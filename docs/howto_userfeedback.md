# User Feedback Configuration

GPT-RAG includes a **User Feedback Loop** feature that lets users evaluate assistant responses through the UI. In the classic default, feedback is processed by the orchestrator and stored in **Cosmos DB**. In the unreleased hosted composition, this Cosmos-backed administrative path exists only when `DEPLOY_ADMINISTRATIVE_PANEL=true`; hosted/no-panel does not provision the panel-only Cosmos dependency. See [Chat runtime modes](deploy.md#chat-runtime-modes-unreleased).

![Feedback stored in Cosmos DB](media/feedback_stored_in_cosmos_db.png)
<br>*User feedback stored in Cosmos DB*

By default, **basic feedback** (thumbs up/down) is enabled, while **detailed ratings** (star rating and comments) are disabled. Administrators control these options through **Azure App Configuration**.

## Feedback Types

When enabled, users can provide **star ratings** and text comments for richer feedback that captures both satisfaction and reasoning.

![User feedback with rating](media/user_feedback_with_rating.png)
<br>*User providing rating and comment feedback*

## Configuration Settings

The behavior of the feedback loop is controlled by key-values in **Azure App Configuration**:

* **ENABLE\_USER\_FEEDBACK** → Default: `true`
  Controls whether the feedback feature is available at all.

![Enable user feedback](media/enable_user_feedback.png)
<BR>*Key to enable or disable user feedback globally*

* **USER\_FEEDBACK\_RATING** → Default: `false`
  Controls whether users can provide detailed feedback with ratings and comments.

![Enable user feedback rating](media/enable_user_feedback_rating.png)
<BR>*Key to enable or disable detailed rating feedback*

## Default Values

* `ENABLE_USER_FEEDBACK = true`
* `USER_FEEDBACK_RATING = false`

This means feedback is collected by default, but **star ratings and comments** must be explicitly enabled by setting `USER_FEEDBACK_RATING` to `true`.
