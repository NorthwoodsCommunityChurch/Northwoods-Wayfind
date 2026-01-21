# URL Parameters

The digital signage display supports URL parameters to customize what events are shown.

## Room Filtering

Filter events to show only those in a specific room or location.

**Parameter:** `room`

**Usage:** `http://localhost:8080?room=RoomName`

### How It Works

- **Case-insensitive** - `?room=auditorium` matches "Auditorium", "AUDITORIUM", etc.
- **Partial match** - `?room=Youth` matches "Youth Room", "Youth Center", "Main Youth Hall"
- **Matches against `SpacesToDisplay`** - The location field from eSpace

### Examples

| URL | Shows Events In |
|-----|-----------------|
| `http://localhost:8080` | All locations |
| `http://localhost:8080?room=Auditorium` | Auditorium only |
| `http://localhost:8080?room=Youth` | Any room containing "Youth" |
| `http://localhost:8080?room=Room%20101` | Room 101 (use %20 for spaces) |

### Visual Indicator

When a room filter is active, a badge appears in the header next to the logo showing the filter value.

## Use Cases

1. **Room-specific displays** - Mount a screen outside each room showing only that room's schedule
2. **Department displays** - Filter by area name to show all youth events, all worship events, etc.
3. **Building zones** - Filter by building wing or floor

## No Matching Events

If the filter results in zero events, the display shows the standard welcome slides:
- "Welcome to Northwoods"
- "Need Assistance?"
- Current time display
