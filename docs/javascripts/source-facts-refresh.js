(function () {
  var REFRESH_TTL_MS = 5 * 60 * 1000; // 5 minutes
  var LAST_REFRESH_KEY = "gpt-rag-source-facts-last-refresh";

  function getNow() {
    return Date.now();
  }

  function shouldRefresh() {
    try {
      var last = Number(localStorage.getItem(LAST_REFRESH_KEY) || "0");
      return getNow() - last >= REFRESH_TTL_MS;
    } catch (e) {
      return true;
    }
  }

  function markRefreshed() {
    try {
      localStorage.setItem(LAST_REFRESH_KEY, String(getNow()));
    } catch (e) {
      // Ignore storage failures.
    }
  }

  function getSourceFacts() {
    try {
      var raw = sessionStorage.getItem("__source");
      if (!raw) {
        return null;
      }
      return JSON.parse(raw);
    } catch (e) {
      return null;
    }
  }

  function setSourceFacts(facts) {
    try {
      sessionStorage.setItem("__source", JSON.stringify(facts));
    } catch (e) {
      // Ignore storage failures.
    }
  }

  function updateVersionInDom(version) {
    var nodes = document.querySelectorAll(".md-source__fact--version");
    for (var i = 0; i < nodes.length; i += 1) {
      nodes[i].textContent = version;
    }
  }

  async function refreshVersionIfStale() {
    if (!shouldRefresh()) {
      return;
    }

    var cachedFacts = getSourceFacts();
    if (!cachedFacts || !cachedFacts.version) {
      // Theme will fetch facts on first load when cache is missing.
      return;
    }

    try {
      var response = await fetch("https://api.github.com/repos/azure/gpt-rag/releases/latest", {
        cache: "no-store",
        headers: {
          Accept: "application/vnd.github+json"
        }
      });

      if (!response.ok) {
        return;
      }

      var payload = await response.json();
      var latestVersion = payload && payload.tag_name ? String(payload.tag_name) : "";
      if (!latestVersion) {
        return;
      }

      if (latestVersion !== cachedFacts.version) {
        cachedFacts.version = latestVersion;
        setSourceFacts(cachedFacts);
        updateVersionInDom(latestVersion);
      }

      markRefreshed();
    } catch (e) {
      // Network failures should not affect page rendering.
    }
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", function () {
      setTimeout(refreshVersionIfStale, 500);
    });
  } else {
    setTimeout(refreshVersionIfStale, 500);
  }
})();
