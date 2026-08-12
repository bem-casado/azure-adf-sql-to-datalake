#!/usr/bin/env python3
"""Validação estática, sem dependências externas, dos artefatos do laboratório."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from typing import Any, Iterable


ROOT = Path(__file__).resolve().parents[1]
ADF_ROOT = ROOT / "adf"
PLACEHOLDER_PATTERN = re.compile(r"__[A-Z0-9_]+__")
ALLOWED_PLACEHOLDERS = {
    "__STORAGE_ACCOUNT_NAME__",
    "__KEY_VAULT_NAME__",
    "__AZURE_SQL_SERVER_NAME__",
    "__AZURE_SQL_DATABASE_NAME__",
    "__ON_PREM_SQL_SERVER__",
    "__ON_PREM_SQL_DATABASE__",
    "__ON_PREM_SQL_USER__",
    "__ON_PREM_PASSWORD_SECRET_NAME__",
}


def walk(value: Any) -> Iterable[Any]:
    yield value
    if isinstance(value, dict):
        for child in value.values():
            yield from walk(child)
    elif isinstance(value, list):
        for child in value:
            yield from walk(child)


def nested_activities(activity: dict[str, Any]) -> Iterable[dict[str, Any]]:
    yield activity
    properties = activity.get("typeProperties", {})
    for key in ("activities", "ifTrueActivities", "ifFalseActivities"):
        for child in properties.get(key, []):
            yield from nested_activities(child)


def fail(errors: list[str], message: str) -> None:
    errors.append(message)


def main() -> int:
    errors: list[str] = []
    artifacts: dict[str, dict[str, dict[str, Any]]] = {}
    all_text = ""

    for folder in ("integrationRuntime", "linkedService", "dataset", "pipeline"):
        artifacts[folder] = {}
        for path in sorted((ADF_ROOT / folder).glob("*.json")):
            text = path.read_text(encoding="utf-8")
            all_text += text
            try:
                artifact = json.loads(text)
            except json.JSONDecodeError as exc:
                fail(errors, f"JSON inválido em {path.relative_to(ROOT)}: {exc}")
                continue

            name = artifact.get("name")
            if not name or not isinstance(artifact.get("properties"), dict):
                fail(errors, f"Artefato incompleto em {path.relative_to(ROOT)}")
                continue
            if path.stem != name:
                fail(errors, f"Nome interno {name!r} difere do arquivo {path.name!r}")
            if name in artifacts[folder]:
                fail(errors, f"Nome duplicado em {folder}: {name}")
            artifacts[folder][name] = artifact

            found_placeholders = set(PLACEHOLDER_PATTERN.findall(text))
            unknown = found_placeholders - ALLOWED_PLACEHOLDERS
            if unknown:
                fail(errors, f"Placeholders desconhecidos em {path.name}: {sorted(unknown)}")

    reference_targets = {
        "LinkedServiceReference": "linkedService",
        "DatasetReference": "dataset",
        "IntegrationRuntimeReference": "integrationRuntime",
        "PipelineReference": "pipeline",
    }

    for folder, named_artifacts in artifacts.items():
        for name, artifact in named_artifacts.items():
            for node in walk(artifact):
                if not isinstance(node, dict):
                    continue
                reference_type = node.get("type")
                target_folder = reference_targets.get(reference_type)
                if not target_folder:
                    continue
                reference_name = node.get("referenceName")
                if reference_name not in artifacts[target_folder]:
                    fail(
                        errors,
                        f"Referência quebrada em {folder}/{name}: "
                        f"{reference_type} {reference_name!r}",
                    )

    for name, artifact in artifacts["pipeline"].items():
        top_level = artifact["properties"].get("activities", [])
        copy_activities = [
            activity
            for root_activity in top_level
            for activity in nested_activities(root_activity)
            if activity.get("type") == "Copy"
        ]
        if not copy_activities:
            fail(errors, f"Pipeline {name} não contém Copy Activity")
        for activity in copy_activities:
            activity_name = activity.get("name", "<sem nome>")
            policy = activity.get("policy", {})
            if policy.get("retry", 0) < 2:
                fail(errors, f"{name}/{activity_name}: retry deve ser pelo menos 2")
            if not policy.get("timeout"):
                fail(errors, f"{name}/{activity_name}: timeout ausente")
            if activity.get("typeProperties", {}).get("validateDataConsistency") is not True:
                fail(errors, f"{name}/{activity_name}: validação de consistência ausente")

    required_artifacts = {
        "integrationRuntime": {"ir-selfhosted-onprem"},
        "linkedService": {
            "ls_key_vault",
            "ls_adls_gen2",
            "ls_sql_onprem",
            "ls_azure_sql",
        },
        "dataset": {
            "ds_sql_onprem_table",
            "ds_azure_sql_table",
            "ds_adls_delimited",
        },
        "pipeline": {
            "pl_ingest_onprem_sql_to_raw",
            "pl_ingest_azure_sql_to_raw",
            "pl_promote_raw_to_bronze",
        },
    }
    for folder, required_names in required_artifacts.items():
        missing = required_names - artifacts[folder].keys()
        if missing:
            fail(errors, f"Artefatos ausentes em {folder}: {sorted(missing)}")

    for layer in ('"raw"', '"bronze"'):
        if layer not in all_text:
            fail(errors, f"Camada {layer} não aparece nos artefatos")

    onprem = artifacts["linkedService"].get("ls_sql_onprem", {})
    password = (
        onprem.get("properties", {})
        .get("typeProperties", {})
        .get("password", {})
    )
    if password.get("type") != "AzureKeyVaultSecret":
        fail(errors, "A senha do SQL local deve ser uma referência AzureKeyVaultSecret")

    adls = artifacts["linkedService"].get("ls_adls_gen2", {})
    adls_properties = adls.get("properties", {}).get("typeProperties", {})
    forbidden_storage_credentials = {"accountKey", "sasUri", "servicePrincipalCredential"}
    if forbidden_storage_credentials.intersection(adls_properties):
        fail(errors, "O linked service do ADLS deve usar identidade gerenciada")

    if errors:
        print("VALIDAÇÃO FALHOU", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    count = sum(len(items) for items in artifacts.values())
    print(f"OK: {count} artefatos ADF válidos, referências íntegras e sem segredo literal.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
