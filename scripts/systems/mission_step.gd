extends Resource

enum Kind { REACH, ENTER_TRANSPORT, INTERACT_NPC, PARK_AND_EXIT, CHASE }

@export var kind := Kind.REACH
@export var objective := ""
@export var subtitle := ""
@export var contact_name := ""
@export var auto_conversation := false
## Alternating lines, beginning with the contact.
@export var conversation: PackedStringArray
@export var inspection_subject: NodePath
@export var cash_total := 0
@export var cash_share := 0
@export var settles_payment := false
@export var keep_on_retry := false
## Relative to the district root. Leave empty for a transport stage that accepts any vehicle.
@export var target: NodePath
@export_range(0.3, 12.0, 0.1) var radius := 2.0
@export var on_foot_only := false
## Relative path to the vehicle the player must be riding at a REACH objective.
@export var required_transport: NodePath
