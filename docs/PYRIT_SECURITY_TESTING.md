# PyRIT Security Testing

### Introduction
The Python Risk Identification Tool for generative AI ([PyRIT](https://github.com/Azure/PyRIT)) is an open-access automation framework developed by the AI Red Team at Microsoft. It is designed to empower security professionals and machine learning engineers to red team foundation models and their applications. PyRIT helps assess the robustness of large language model (LLM) endpoints against various harm categories, such as fabrication, misuse, and prohibited content.

### Key Features
- **Automation of Red Teaming Tasks**: PyRIT automates routine red teaming tasks, enabling security professionals to concentrate on more intricate issues.
- **Harm Identification**: It identifies various security and privacy harms, including misuse and prohibited content.
- **Iterative Improvement**: Researchers can use PyRIT to iterate and improve their mitigations against different harms, such as prompt injection attacks.

### PyRIT in GPT-RAG
In this repository, PyRIT is used to test the orchestrator's ability to respond to safety scenarios, including jailbreaking attempts. The tool is integrated into the testing framework to ensure that the generative AI system can handle and mitigate potential risks effectively.

### Test Descriptions

### Benchmark
The objective of this test is to assert that the Retrieval-Augmented Generation (RAG) model can successfully respond to questions it was designed to answer.

### Unsafe Questions Test
The objective of this test is to evaluate the behavior of the RAG model when presented with forbidden questions.

### Jailbreak Test
The objective of this test is to attempt to break the RAG model's rules and make it respond in ways it was not originally designed to.

### Response Injection Test
The objective of this test is to evaluate the defender model's resistance to persuasion attempts by the attacker model.

### Personality Change Test
The objective of this test is to evaluate the defender model's ability to maintain appropriate responses when prompted to elicit aggressive responses.

### Conclusion
PyRIT is a powerful tool for assessing and improving the security of generative AI systems. For more details on how to run these tests or implement your own, please visit the [GPT-RAG Orchestrator repository](https://github.com/Azure/gpt-rag-orchestrator).