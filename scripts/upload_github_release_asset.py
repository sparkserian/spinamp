#!/usr/bin/env python3
import json
import mimetypes
import pathlib
import subprocess
import os
import sys
import urllib.error
import urllib.parse
import urllib.request


def fail(message: str) -> None:
    print(message, file=sys.stderr)
    raise SystemExit(1)


def github_request(
    url: str,
    token: str,
    *,
    method: str = "GET",
    data=None,
    content_type: str | None = None,
    allow_not_found: bool = False,
):
    request = urllib.request.Request(url, method=method)
    request.add_header("Accept", "application/vnd.github+json")
    request.add_header("Authorization", f"Bearer {token}")
    request.add_header("X-GitHub-Api-Version", "2022-11-28")
    if content_type is not None:
        request.add_header("Content-Type", content_type)
    if data is not None and isinstance(data, str):
        data = data.encode("utf-8")
    try:
        with urllib.request.urlopen(request, data=data) as response:
            body = response.read()
            if not body:
                return None
            return json.loads(body)
    except urllib.error.HTTPError as exc:
        if allow_not_found and exc.code == 404:
            return None
        details = exc.read().decode("utf-8", errors="replace")
        fail(f"GitHub API request failed ({exc.code} {exc.reason}): {details}")


def github_binary_upload(url: str, token: str, asset_path: pathlib.Path) -> None:
    content_type = mimetypes.guess_type(asset_path.name)[0] or "application/octet-stream"
    request = urllib.request.Request(url, method="POST")
    request.add_header("Accept", "application/vnd.github+json")
    request.add_header("Authorization", f"Bearer {token}")
    request.add_header("X-GitHub-Api-Version", "2022-11-28")
    request.add_header("Content-Type", content_type)
    with asset_path.open("rb") as handle:
        payload = handle.read()
    try:
        with urllib.request.urlopen(request, data=payload):
            return
    except urllib.error.HTTPError as exc:
        details = exc.read().decode("utf-8", errors="replace")
        fail(f"GitHub asset upload failed ({exc.code} {exc.reason}): {details}")


def main() -> None:
    if len(sys.argv) < 2:
        fail("usage: upload_github_release_asset.py <asset-path> [tag]")

    asset_path = pathlib.Path(sys.argv[1]).expanduser().resolve()
    if not asset_path.exists():
        fail(f"asset not found: {asset_path}")

    repo_root = pathlib.Path(__file__).resolve().parents[1]
    version_script = repo_root / "scripts" / "release_version.sh"
    default_tag = subprocess.check_output([str(version_script), "artifact"], text=True).strip()
    tag_name = sys.argv[2] if len(sys.argv) > 2 else default_tag

    owner = os.environ.get("GH_RELEASE_OWNER", "").strip()
    repo = os.environ.get("GH_RELEASE_REPO", "").strip()
    token = os.environ.get("GH_TOKEN", "").strip()

    if not owner or not repo or not token:
        fail("GH_RELEASE_OWNER, GH_RELEASE_REPO, and GH_TOKEN must be set")

    release_api_base = f"https://api.github.com/repos/{owner}/{repo}/releases"

    release = github_request(
        f"{release_api_base}/tags/{urllib.parse.quote(tag_name)}",
        token,
        allow_not_found=True,
    )

    if release is None:
        release = github_request(
            release_api_base,
            token,
            method="POST",
            data=json.dumps(
                {
                    "tag_name": tag_name,
                    "name": tag_name,
                    "draft": False,
                    "prerelease": False,
                    "generate_release_notes": True,
                }
            ),
            content_type="application/json",
        )

    assets = release.get("assets", [])
    existing = next((asset for asset in assets if asset.get("name") == asset_path.name), None)
    if existing is not None:
        github_request(existing["url"], token, method="DELETE")

    upload_url_template = release["upload_url"]
    upload_url = upload_url_template.split("{", 1)[0]
    upload_url = f"{upload_url}?name={urllib.parse.quote(asset_path.name)}"
    github_binary_upload(upload_url, token, asset_path)

    print(f"Uploaded {asset_path.name} to {owner}/{repo} release {tag_name}")


if __name__ == "__main__":
    main()
