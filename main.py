import re

import requests

def define_env(env):
    @env.macro
    def latest_release(repo="azure/gpt-rag"):
        url = f"https://github.com/{repo}/releases/latest"
        r = requests.get(url, allow_redirects=True)
        return r.url.split("/")[-1] 

    def _get_latest_prerelease(repo: str, prefer_rc: bool = True) -> dict | None:
        api_url = f"https://api.github.com/repos/{repo}/releases?per_page=50"
        try:
            r = requests.get(
                api_url,
                headers={"Accept": "application/vnd.github+json"},
                timeout=10,
            )
            r.raise_for_status()
            releases = r.json() or []
        except Exception:
            return None

        prereleases = [rel for rel in releases if rel.get("prerelease")]
        if not prereleases:
            return None

        if prefer_rc:
            rc_re = re.compile(r"(?:^|[-._])rc(?:[-._]|$)", re.IGNORECASE)
            for rel in prereleases:
                tag = rel.get("tag_name", "")
                name = rel.get("name", "")
                if rc_re.search(tag) or rc_re.search(name):
                    return rel

        return prereleases[0]

    @env.macro
    def latest_release_candidate(repo: str = "azure/gpt-rag") -> str:
        rel = _get_latest_prerelease(repo)
        return (rel or {}).get("tag_name", "")

    @env.macro
    def latest_release_candidate_url(repo: str = "azure/gpt-rag") -> str:
        rel = _get_latest_prerelease(repo)
        return (rel or {}).get("html_url", f"https://github.com/{repo}/releases")
