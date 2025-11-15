import requests

def define_env(env):
    @env.macro
    def latest_release(repo="azure/gpt-rag"):
        url = f"https://github.com/{repo}/releases/latest"
        r = requests.get(url, allow_redirects=True)
        return r.url.split("/")[-1] 
