# <!-- empty title -->

<style>
.team-grid {
  display: flex;
  flex-wrap: wrap;
  justify-content: center;
  gap: 2rem;
  margin: 1.5rem 0 2rem 0;
}

.team-card {
  text-align: center;
  width: 120px;
  transition: transform 0.2s ease, box-shadow 0.2s ease;
  border-radius: 12px;
  padding: 10px;
}

.team-card:hover {
  transform: translateY(-6px);
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.12);
  background-color: rgba(240, 240, 240, 0.3);
}

.team-card img {
  width: 80px;
  height: 80px;
  border-radius: 50%;
  border: 2px solid #ccc;
  object-fit: cover;
}

.team-card sub {
  display: block;
  margin-top: 6px;
  color: #555;
}

.section-title {
  font-size: 1.1rem;
  font-weight: 600;
  margin-top: 2.5rem;
  text-align: center;
  color: #333;
}

.section-desc {
  text-align: center;
  color: #666;
  font-size: 0.95rem;
  margin-top: 0.3rem;
  margin-bottom: 1.5rem;
}

.call-to-action {
  text-align: center;
  margin-top: 3rem;
  font-size: 1rem;
  color: #333;
}
.call-to-action a {
  font-weight: 600;
  text-decoration: none;
  color: #0078d4;
}
.call-to-action a:hover {
  text-decoration: underline;
}
</style>

<div class="section-title">Core Team</div>
<div class="section-desc">Leads the direction, development, and continuous evolution of GPT-RAG.</div>

<div class="team-grid">
  <div class="team-card">
    <a href="https://github.com/placerda" target="_blank">
      <img src="https://github.com/placerda.png" alt="Paulo Lacerda">
      <sub><b>Paulo Lacerda</b></sub>
      <sub>Project Lead</sub>
    </a>
  </div>
  <div class="team-card">
    <a href="https://github.com/vladborys" target="_blank">
      <img src="https://github.com/vladborys.png" alt="Vlad Borys">
      <sub><b>Vlad Borys</b></sub>
      <sub>Reviewer</sub>
    </a>
  </div>
  <div class="team-card">
    <a href="https://github.com/gbecerra1982" target="_blank">
      <img src="https://github.com/gbecerra1982.png" alt="Gonzalo Becerra">
      <sub><b>Gonzalo Becerra</b></sub>
      <sub>Reviewer</sub>      
    </a>
  </div>  
</div>

---

<div class="section-title">Engineering Advisor</div>
<div class="section-desc">Provides technical guidance and ensures architectural alignment with best practices.</div>

<div class="team-grid">
  <div class="team-card">
    <a href="https://github.com/pablocastro" target="_blank">
      <img src="https://github.com/pablocastro.png" alt="Pablo Castro">
      <sub><b>Pablo Castro</b></sub>
      <sub>Engineering Advisor</sub>
    </a>
  </div>
</div>
 
---

<div class="section-title">Founders</div>
<div class="section-desc">The visionaries who laid the foundation and shaped GPT-RAG from the ground up.</div>

<div class="team-grid">
  <div class="team-card">
    <a href="https://github.com/placerda" target="_blank">
      <img src="https://github.com/placerda.png" alt="Paulo Lacerda">
      <sub><b>Paulo Lacerda</b></sub>
    </a>
  </div>
  <div class="team-card">
    <a href="https://github.com/gbecerra1982" target="_blank">
      <img src="https://github.com/gbecerra1982.png" alt="Gonzalo Becerra">
      <sub><b>Gonzalo Becerra</b></sub>
    </a>
  </div>
  <div class="team-card">
    <a href="https://github.com/Martin-Sciarrillo" target="_blank">
      <img src="https://github.com/Martin-Sciarrillo.png" alt="Martin Sciarrilo">
      <sub><b>Martin Sciarrilo</b></sub>
    </a>
  </div>
</div>

---

<div class="section-title">Contributors</div>
<div class="section-desc">Every contribution matters — code, documentation, ideas, or feedback.</div>

<div style="display: flex; flex-direction: column; align-items: center; gap: 3rem; margin-top: 2rem;">

  <div style="text-align: center;">
    <a href="https://github.com/Azure/gpt-rag/graphs/contributors" target="_blank">
      <img src="https://contrib.rocks/image?repo=Azure/gpt-rag" alt="GPT-RAG Core Contributors" title="GPT-RAG Core" />
    </a>
    <div style="margin-top: 0.8rem; font-size: 0.95rem; color: #555;">GPT-RAG</div>
  </div>

  <div style="text-align: center;">
    <a href="https://github.com/Azure/gpt-rag-orchestrator/graphs/contributors" target="_blank">
      <img src="https://contrib.rocks/image?repo=Azure/gpt-rag-orchestrator" alt="GPT-RAG Orchestrator Contributors" title="GPT-RAG Orchestrator" />
    </a>
    <div style="margin-top: 0.8rem; font-size: 0.95rem; color: #555;">Orchestrator</div>
  </div>

  <div style="text-align: center;">
    <a href="https://github.com/Azure/gpt-rag-ingestion/graphs/contributors" target="_blank">
      <img src="https://contrib.rocks/image?repo=Azure/gpt-rag-ingestion" alt="GPT-RAG Ingestion Contributors" title="GPT-RAG Ingestion" />
    </a>
    <div style="margin-top: 0.8rem; font-size: 0.95rem; color: #555;">Ingestion</div>
  </div>

  <div style="text-align: center;">
    <a href="https://github.com/Azure/gpt-rag-ui/graphs/contributors" target="_blank">
      <img src="https://contrib.rocks/image?repo=Azure/gpt-rag-ui" alt="GPT-RAG UI Contributors" title="GPT-RAG UI" />
    </a>
    <div style="margin-top: 0.8rem; font-size: 0.95rem; color: #555;">UI</div>
  </div>

  <div style="text-align: center;">
    <a href="https://github.com/Azure/gpt-rag-mcp/graphs/contributors" target="_blank">
      <img src="https://contrib.rocks/image?repo=Azure/gpt-rag-mcp" alt="GPT-RAG MCP Contributors" title="GPT-RAG MCP" />
    </a>
    <div style="margin-top: 0.8rem; font-size: 0.95rem; color: #555;">MCP</div>
  </div>

</div>

---

<div class="section-title">Champions</div>
<div class="section-desc">Community advocates helping users succeed, sharing knowledge, and growing the GPT-RAG ecosystem.</div>

<div class="team-grid">
  <div class="team-card">
    <a href="https://github.com/RameshJGenAI" target="_blank">
      <img src="https://github.com/RameshJGenAI.png" alt="Ramesh Jajula">
      <sub><b>Ramesh Jajula</b></sub>
    </a>
  </div>
  <div class="team-card">
    <a href="https://github.com/Vinod-Chekkala" target="_blank">
      <img src="https://github.com/Vinod-Chekkala.png" alt="Vinod Kumar Chekkala">
      <sub><b>Vinod Chekkala</b></sub>
    </a>
  </div>
  <div class="team-card">
    <a href="https://github.com/v-sisaurabh" target="_blank">
      <img src="https://github.com/v-sisaurabh.png" alt="Saurabh Singh">
      <sub><b>Saurabh Singh</b></sub>
    </a>
  </div>
  <div class="team-card">
    <a href="https://github.com/varunb17" target="_blank">
      <img src="https://github.com/varunb17.png" alt="Varun Nambia">
      <sub><b>Varun Nambia</b></sub>
    </a>
  </div>  
</div>

---

<div class="call-to-action">
  <p>Every contribution matters! Whether it's code, docs, ideas, or feedback — you help make GPT-RAG better.</p>
  <p>👉 <a href="../contributing">Learn how to contribute</a></p>
</div>
