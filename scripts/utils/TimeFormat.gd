extends RefCounted
class_name TimeFormat

# Shared player-facing time formatting helpers.
# Uses fixed-width HHhMMmSSs output for both duration and countdown labels.


static func format_seconds_hms(total_seconds: int) -> String:
	var clamped_seconds := maxi(0, total_seconds)
	var hours := int(clamped_seconds / 3600.0)
	var minutes := int((clamped_seconds % 3600) / 60.0)
	var seconds := clamped_seconds % 60
	return "%02dh%02dm%02ds" % [hours, minutes, seconds]


static func format_minutes_hms(total_minutes: int) -> String:
	return format_seconds_hms(maxi(0, total_minutes) * 60)
