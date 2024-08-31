# Security Hub Function

## Overview
The Security Hub Function integrates with Azure Content Safety and centralizes GPT Responsible AI checks. This function ensures that AI-generated content adheres to safety and ethical standards.

## Features

### Groundedness Detection 
The Groundedness Detection evaluates whether the text responses of large language models (LLMs) are grounded in the source materials provided by users. Ungroundedness refers to instances where LLMs produce information that is non-factual or inaccurate compared to the source materials.

### Prompt Shields
Generative AI models can be exploited by malicious actors. To mitigate these risks, safety mechanisms are integrated to restrict the behavior of LLMs within a safe operational scope. Despite these safeguards, LLMs can still be vulnerable to adversarial inputs that bypass the integrated safety protocols. Prompt Shields analyzes LLM inputs and detects User Prompt Attacks

### Protected Material Detection
The Protected Material Text check flags known text content (e.g., song lyrics, articles, recipes, and selected web content) that might be output by large language models.

### Harm Categories
Content Safety recognizes four distinct categories of objectionable content:

#### Hate and Fairness
Hate and fairness-related harms refer to any content that attacks or uses pejorative or discriminatory language with reference to a person or identity group based on certain differentiating attributes, including but not limited to race, ethnicity, nationality, gender identity and expression, sexual orientation, religion, immigration status, ability status, personal appearance, and body size.

Fairness is concerned with ensuring that AI systems treat all groups of people equitably without contributing to existing societal inequities. Similar to hate speech, fairness-related harms hinge upon disparate treatment of identity groups.

#### Sexual
Sexual content describes language related to anatomical organs and genitals, romantic relationships, acts portrayed in erotic or affectionate terms, pregnancy, physical sexual acts (including those portrayed as assault or forced sexual violent acts against one's will), prostitution, pornography, and abuse.

#### Violence
Violence describes language related to physical actions intended to hurt, injure, damage, or kill someone or something. It also includes descriptions of weapons, guns, and related entities, such as manufacturers, associations, and legislation.

#### Self-Harm
Self-harm describes language related to physical actions intended to purposely hurt, injure, or damage one's body or kill oneself.


## Security hub implementation
- Deploy the [security hub function](https://github.com/Azure/gpt-rag-securityhub)
- Create a content safety resource
- Add eviroment variables to security hub:
    "CONTENT_SAFETY_ENDPOINT": "https://{your-content-safety-resource}.cognitiveservices.azure.com/",
    "AZURE_KEY_VAULT_NAME": "{your-keyVault-resource}",
- Add function key to keyvault with name "securityHubKey" and content safety key with name "contentSafetyKey"
- Add enviroment variables to orchestrator:
    "SECURITY_HUB_ENDPOINT": "https://{your-securityHub-function-url}/api/SecurityHub",
    "SECURITY_HUB_CHECK": "true",
- OPTIONAL: To customize threshholds of harm and groundedness checks, add these env variables to orchestrator with your prefered values:
    "SECURITY_HUB_HATE_THRESHHOLD": "0",
    "SECURITY_HUB_SELFHARM_THRESHHOLD": "0",
    "SECURITY_HUB_SEXUAL_THRESHHOLD": ""0,
    "SECURITY_HUB_VIOLENCE_THRESHHOLD": "0",
    "SECURITY_HUB_UNGROUNDED_PERCENTAGE_THRESHHOLD":"0.0

    Harm categories must be an int value beetween 0 and 4
    Ungroundedness percentage must be a float value beetween 0 and 1