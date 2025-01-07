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

### Block lists
Create lists of words that should never be used and filter queries and answers that include them.

### Responsible AI
Conduct comprehensive evaluations to ensure that the AI system adheres to responsible AI principles. These principles are designed to guide the development and deployment of AI technologies in a manner that is ethical, transparent, and fair.

#### Fairness
This check is dedicated to ensuring that the AI system treats all groups of people equitably. It aims to prevent the AI from contributing to or exacerbating existing societal inequities. The fairness check evaluates the AI's decision-making processes to ensure that they do not favor or discriminate against any particular group based on attributes such as race, gender, age, or socioeconomic status.

### Auditing
This feature provides an endpoint that logs all interactions with the orchestrator. The purpose of this auditing capability is to maintain a detailed record of all activities and decisions made by the AI system. These logs are crucial for transparency and accountability, allowing for thorough reviews and analyses of the AI's behavior and ensuring compliance with ethical standards and regulatory requirements.

## Security hub implementation
- Deploy the [security hub function](https://github.com/Azure/gpt-rag-securityhub)
- Create a content safety resource
- Give the security hub function the roles of Cognitive Services Users and Reader in the content safety resource. 
- Add eviroment variables to security hub:
    "CONTENT_SAFETY_ENDPOINT": "https://{your-content-safety-resource}.cognitiveservices.azure.com/",
- Add enviroment variables to orchestrator:
    "SECURITY_HUB_ENDPOINT": "https://{your-securityHub-function-url}/api",
    "SECURITY_HUB_CHECK": "true",

- OPTIONAL: 
- To customize threshholds of harm and groundedness checks, add these env variables to orchestrator with your prefered values:
    "SECURITY_HUB_HATE_THRESHHOLD": "0",
    "SECURITY_HUB_SELFHARM_THRESHHOLD": "0",
    "SECURITY_HUB_SEXUAL_THRESHHOLD": ""0,
    "SECURITY_HUB_VIOLENCE_THRESHHOLD": "0",
    "SECURITY_HUB_UNGROUNDED_PERCENTAGE_THRESHHOLD":"0.0

    Harm categories must be an int value beetween 0 and 4
    Ungroundedness percentage must be a float value beetween 0 and 1

- If responsible AI checks are to be conducted, the following environment variables must be set with correct values, and the Cognitive Services OpenAI User role is needed in the AOAI service:
        "RESPONSIBLE_AI_CHECK": "True",
        "AZURE_OPENAI_RESOURCE": "",
        "AZURE_OPENAI_CHATGPT_DEPLOYMENT": "",
        "AZURE_OPENAI_CHATGPT_MODEL": ""

- If the content safety service is consumed via APIM, you need to have a Key Vault with a secret that contains the APIM key named "apimSubscriptionKey" and set these environment variables:
        "APIM_ENABLED": "true",
        "AZURE_KEY_VAULT_NAME": "",
        "APIM_ENDPOINT": ""

    Additionally, roles are needed to read the secret from the Key Vault.

- You can also add this optional variables if you want to add your blocklists(you should first [create and fill the blocklist](https://learn.microsoft.com/en-us/azure/ai-services/content-safety/how-to/use-blocklist?tabs=windows%2Crest#create-or-modify-a-blocklist)):
        "BLOCK_LIST_CHECK": "true",
        "BLOCK_LISTS_NAMES": [names]