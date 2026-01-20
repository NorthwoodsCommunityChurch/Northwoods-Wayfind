# eSpace Digital Signage API Documentation

## Overview

The eSpace facility management platform provides a Digital Signage API for retrieving scheduled events to display on digital signs.

## Base URL

```
https://app.espace.cool/FacilieSpace/DigitalSignage/
```

## Authentication

All requests require an API key passed as a query parameter:

```
?key=YOUR_API_KEY
```

## Endpoints

### Get Display Events

Retrieves all events configured to display on a specific digital sign.

**Endpoint:** `GET /GetDisplayEvents/{DISPLAY_ID}`

**Full URL:** `https://app.espace.cool/FacilieSpace/DigitalSignage/GetDisplayEvents/{DISPLAY_ID}?key={API_KEY}`

**Parameters:**
| Parameter | Type | Location | Description |
|-----------|------|----------|-------------|
| DISPLAY_ID | integer | URL path | The ID of the digital display |
| key | string | Query string | API authentication key |

**Example Request:**
```
GET https://app.espace.cool/FacilieSpace/DigitalSignage/GetDisplayEvents/7?key=abc123
```

## Response Format

Returns a JSON array of event objects.

### Event Object Structure

| Field | Type | Description |
|-------|------|-------------|
| `EventName` | string | Internal event name |
| `DisplayName` | string | Public display name (use this if available) |
| `Description` | string | Event description (optional) |
| `SpacesToDisplay` | string | Location/room name(s) |
| `EventStart` | string | Start time in .NET date format |
| `EventEnd` | string | End time in .NET date format |
| `EventTimeDisplay` | string | Pre-formatted time string (e.g., "9:00 AM - 10:00 AM") |
| `IsAnnouncement` | boolean | If true, display as announcement (no time/location) |
| `IsHiddenFromDisplay` | boolean | If true, should not be shown |
| `BackgroundfileUrl` | string | URL to background image/video (optional) |
| `TextColor` | string | Custom text color (optional) |
| `BackgroundColor` | string | Custom background color (optional) |

### .NET Date Format

The API returns dates in Microsoft's .NET JSON date format:

```
/Date(1234567890000)/
```

The number is a Unix timestamp in milliseconds. **Important:** The API sends local time encoded as if it were UTC, so you need to interpret the UTC values as local time.

**Parsing Example (JavaScript):**
```javascript
function parseNetDate(dateString) {
    if (!dateString) return null;
    const match = dateString.match(/\/Date\((\d+)([+-]\d{4})?\)\//);
    if (match) {
        const timestamp = parseInt(match[1]);
        // Interpret UTC values as local time
        const utcDate = new Date(timestamp);
        const localDate = new Date(
            utcDate.getUTCFullYear(),
            utcDate.getUTCMonth(),
            utcDate.getUTCDate(),
            utcDate.getUTCHours(),
            utcDate.getUTCMinutes(),
            utcDate.getUTCSeconds()
        );
        return localDate;
    }
    return new Date(dateString);
}
```

### Example Response

```json
[
    {
        "EventName": "Sunday Service",
        "DisplayName": "Weekend Worship",
        "Description": "Join us for worship and teaching",
        "SpacesToDisplay": "Main Auditorium",
        "EventStart": "/Date(1705766400000)/",
        "EventEnd": "/Date(1705773600000)/",
        "EventTimeDisplay": "9:00 AM - 11:00 AM",
        "IsAnnouncement": false,
        "IsHiddenFromDisplay": false,
        "BackgroundfileUrl": null,
        "TextColor": null,
        "BackgroundColor": null
    },
    {
        "EventName": "Building Closed Notice",
        "DisplayName": "Building Closed Monday",
        "Description": null,
        "SpacesToDisplay": null,
        "EventStart": "/Date(1705852800000)/",
        "EventEnd": "/Date(1705939200000)/",
        "EventTimeDisplay": "",
        "IsAnnouncement": true,
        "IsHiddenFromDisplay": false,
        "BackgroundfileUrl": null,
        "TextColor": "#FFFFFF",
        "BackgroundColor": "#FF6900"
    }
]
```

## CORS

The eSpace API does **not** include CORS headers, so browser-based requests will fail. You must proxy requests through a server.

**Proxy Example (Node.js):**
```javascript
if (req.url === '/api/events') {
    https.get(API_URL, (apiRes) => {
        let data = '';
        apiRes.on('data', chunk => data += chunk);
        apiRes.on('end', () => {
            res.writeHead(200, {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            });
            res.end(data);
        });
    });
}
```

## Usage Notes

1. **Display ID**: Each physical digital sign should have its own Display ID in eSpace. Events are assigned to specific displays.

2. **Filtering**: Filter out events where `IsHiddenFromDisplay === true` before displaying.

3. **Sorting**: Events are not guaranteed to be sorted. Sort by `EventStart` after parsing.

4. **Refresh Rate**: Recommended refresh interval is 5-10 minutes to balance freshness with API load.

5. **Display Name Priority**: Use `DisplayName` if available, fall back to `EventName`.

6. **Announcements**: Events with `IsAnnouncement: true` are general announcements without specific times/locations.

## Environment Variables

For the Northwoods implementation:

```bash
ESPACE_API_KEY=your-api-key-here
ESPACE_DISPLAY_ID=7  # Optional, defaults to 7
PORT=8080            # Optional, defaults to 8080
```
