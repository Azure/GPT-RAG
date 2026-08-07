# User Feedback Configuration

GPT-RAG includes a **User Feedback Loop** feature that lets users evaluate
assistant responses through the UI. In the currently released classic
Container Apps topology and the explicit classic fallback, feedback is
processed by the orchestrator and stored in **Cosmos DB**. The published
[hosted component matrix](hosted_agent_release_matrix.md) implements separate
user history, feedback, and delete APIs in UI `v2.6.0`. Hosted-panel is now an
explicit supported topology in the pinned umbrella matrix, but
`PANEL_HISTORY_ENABLED` and `PANEL_HISTORY_OWNER_BINDING_VALIDATED` remain
deployment-published `false`, so these routes continue to return 503 until
their separate evidence procedure completes.

For the component contract, the UI BFF checks the caller's validated `oid`
against the owner index before reading managed Conversation messages or
metadata. Missing and non-owner resources both return opaque 404. Feedback
stores bounded, sanitized rating/category/comment/message-reference metadata
only; message bodies and citations remain in managed Conversations. Delete
removes the managed Conversation first and then metadata, returning an explicit
`partial` result if metadata cleanup fails. Signed pagination cursors are
`oid`-bound and expiring; tampered, expired, or cross-user cursors return 422.
These routes return 503 while panel/history gates are off.

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
