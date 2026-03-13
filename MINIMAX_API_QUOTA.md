# MiniMax Quota API Documentation

This document explains how to interact with the MiniMax API to fetch and parse quota usage details for the MiniMax APIs (like the M2.5 coding models).

## Endpoint Details

- **URL:** `https://www.minimax.io/v1/api/openplatform/coding_plan/remains`
- **Method:** `GET`
- **Content-Type:** `application/json`

## Authentication

The API requires a Bearer token for authentication. You must pass your MiniMax API Key in the `Authorization` header.

**Header Format:**
```http
Authorization: Bearer YOUR_MINIMAX_API_KEY
```

## Example Request

Here is an example of how to fetch the quota using `curl`:

```bash
curl --location --request GET 'https://www.minimax.io/v1/api/openplatform/coding_plan/remains' \
--header 'Authorization: Bearer YOUR_MINIMAX_API_KEY'
```

## Example Response

A successful response (HTTP 200) returns a JSON object containing a `model_remains` array. This array includes the quota details for various models you have access to.

```json
{
  "model_remains": [
    {
      "model_name": "abab6.5g-chat-M2.5",
      "current_interval_total_count": 500,
      "current_interval_usage_count": 450,
      "remains_time": 86400000 
    }
  ]
}
```

## Response Fields

When interpreting the API response, you'll need to extract the relevant object from the `model_remains` array. It is recommended to filter the array by `model_name` (e.g., looking for models containing `"M2.5"`).

| Field Name | Type | Description |
| :--- | :--- | :--- |
| `model_name` | `String` | The identifier for the model (e.g., `"M2.5"` or `"abab6.5g"`). |
| `current_interval_total_count` | `Integer` | The **total quota** allocated for the current billing interval or window. |
| `current_interval_usage_count` | `Integer` | The **remaining quota** available in the current interval. *(Note: Despite containing the word "usage", this field represents items remaining towards your limit)*. |
| `remains_time` | `Integer` | The **time remaining** until the current quota interval resets, represented in **milliseconds**. |

### Derived Metrics

To build a complete picture for the quota UI (like a quota bar), you can calculate the following from the response fields:

1. **Used Quota:**
   `Used = current_interval_total_count - current_interval_usage_count`

2. **Reset Time in Minutes:**
   `Minutes Remaining = remains_time / 1000 / 60`

3. **Usage Percentage:**
   `Percentage = (Used / Total) * 100`

## Error Handling

When interacting with the quota API, ensure you handle the following potential failures gracefully:
- Missing or invalid API key (Typically returns a `401 Unauthorized`).
- Network failures or timeouts.
- Missing `model_remains` key or unexpected JSON format changes in the response payload.
