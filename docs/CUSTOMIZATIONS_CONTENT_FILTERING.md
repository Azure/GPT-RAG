# Configuring AOAI content filters

- [Overview of Responsible AI practices for AOAI models](https://learn.microsoft.com/en-us/legal/cognitive-services/openai/overview?context=%2Fazure%2Fai-services%2Fopenai%2Fcontext%2Fcontext)
- [AOAI Content filtering categories](https://learn.microsoft.com/en-us/azure/ai-services/openai/concepts/content-filter?tabs=warning%2Cpython-new#content-filtering-categories)
- [Apply for unrestricted content filters via this form](https://customervoice.microsoft.com/Pages/ResponsePage.aspx?id=v4j5cvGGr0GRqy180BHbR7en2Ais5pxKtso_Pz4b1_xUMlBQNkZMR0lFRldORTdVQzQ0TEI5Q1ExOSQlQCN0PWcu)

Azd automatically creates content filters profile with default severity threshold *(Medium)* for all content harms categories *(Hate, Violence, Sexual, Self-Harm)* and assignes it to provisioned AOAI model through post deployment script. However, if you want to customize them to be more or less restrictive, you can make changes to [raipolicies.json](../scripts/rai/raipolicies.json) file.

**Example**: Changing filters threshold for violence (prompt) and self-harm (completion) categories
```json
    {
        "name": "violence",
        "blocking": true,
        "enabled": true,
        "allowedContentLevel": "high",
        "source": "prompt"
    },
    {
        "name": "selfharm",
        "blocking": true,
        "enabled": true,
        "allowedContentLevel": "low",
        "source": "completion"
    }
```

(Optional) Content filters also support additional safety models *(Jailbreak, Material Protection for Text or Code)* that can be run on top of the main content filters.

**Example**: Enabling Jailbreak and Text Material protection
```json
{
    
    "name": "jailbreak",
    "blocking": true,
    "source": "prompt",
    "enabled": true
},
{
    "name": "protected_material_text",
    "blocking": true,
    "source": "completion",
    "enabled": true
},
{
    "name": "protected_material_code",
    "blocking": false,
    "source": "completion",
    "enabled": false
}
```

Then, follow regular installation & deployment process.

>Note: You need to make changes in raipolicies.json file before executting ```azd up``` command, if you want to provision and deploy all in once.

In order you update content filters policies for already deployed model, run the following command.

```sh
azd provision
```