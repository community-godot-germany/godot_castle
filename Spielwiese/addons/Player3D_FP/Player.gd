extends KinematicBody

# Export Variablen
export var mouse_sensivity = 0.25

export var gravity = 8.0
export var max_speed = 3.0
export var max_running_speed = 6.0
export var accel = 2.0
export var deaccel = 6.0
export var jump_height = 3.5
export(float, 0.1, 0.5) var max_stair_height = 0.3
export var max_stair_angle = 20

export var max_floor_angle = 45

export var isFlying = false
export var allowChangeFlying = false
export var fly_speed = 10.0
export var fly_accel = 4.0

# Kamera Ausrichtung (für Einschränkung der Neigung, damt nicht im Kreis nach oben und unten gedreht werden kann)
var camera_angle = 0.0

# Relative Maus Bewegung
var mouse_relative = Vector2()

# Wenn Bewegung aktiviert
var isMove = false
var isCrouch = false
var isForeward = false
var isBackward = false

# Iteraktion
var isInteract = false
var interactMethod = ""

# Node Elemente
var Player = self
var Target
var Kopf
var Kamera
var rayTop
var rayStair
var rayStairBack
var rayInteract
var labelAction

# Bewegung Richtung
var direction = Vector3()

# Bewegung stärke
var velocity = Vector3()


# Wenn die Szene geladen ist
func _ready():
	# Dummy Körper ausblenden
	$Visible.visible = false
	
	# Kopf und Kamera merken 
	Kopf = $Kopf
	Kamera = $Kopf/Camera
	rayTop = $Kopf/rayTop
	rayStair = $Kopf/rayStair
	rayStairBack = $Kopf/rayStair2
	rayInteract = $Kopf/Camera/rayInteract
	labelAction = $lblAction
	
	# Bewegung starten
	start_move()

#Interaktion prüfen
func checkInteract():
	if rayInteract.is_colliding():
		# print("colliding")
		Target = rayInteract.get_collider()
		#print(Target)
		if Target.has_method("player_interact"):
			# position lesen
			var pos = rayInteract.get_collision_point()
			
			# fremd Methode aufrufen und Auslesen
			interactMethod = Target.player_interact(pos, Player)
			isInteract = true
			labelAction.text = interactMethod
		else:
			isInteract = false
			labelAction.text = ""
	else:
		#print("not colliding")
		isInteract = false
		labelAction.text = ""
	

# Eingaben prüfen
func _input(event):
	# Richtungen zurücksetzen
	isForeward = false
	isBackward = false
	
	# ESC taste 'ui_cancel'
	if Input.is_action_just_pressed("ui_cancel"):
		# Bewegung deaktivieren
		stop_move()
		
		# Spiel Beenden
		get_tree().quit()

	# Wenn Bewegung eingeschaltet
	if isMove:
		# Interaktion
		if isInteract and Input.is_action_just_pressed("interact"):
			if Target.has_method("do_action"):
				Target.do_action(Player)
				print("test")
		
		# Wenn Maus Bewegung (Umschauen)
		if event is InputEventMouseMotion:
			# relative Mausbewegung merken
			mouse_relative = event.relative
		
		# Wenn Flugmodus umschaltbar
		if allowChangeFlying and Input.is_action_just_pressed("change_fly"):
			#wenn im Flugmodus
			if isFlying:
				isFlying = false
			else:
				isFlying = true
		
		# wenn ducken kriechen
		if Input.is_action_pressed("crouch"):
			if isCrouch == false:
				rayTop.enabled = true
				scale_object_local(Vector3(1, 0.5, 1))
				isCrouch = true
		elif isCrouch:
			if rayTop.is_colliding() == false:
				scale_object_local(Vector3(1, 2, 1))
				isCrouch = false
				rayTop.enabled = false
		
		# Bewegungs Richtung zurücksetzen
		direction = Vector3()
		
		# Kamera Ausrichtung lesen
		var camTransform = Kamera.get_global_transform().basis
		
		# Wenn nach vorne 'move_forward'
		if Input.is_action_pressed("move_forward"):
			direction -= camTransform.z
			isForeward = true

		# Wenn nach hinten 'move_backward'
		if Input.is_action_pressed("move_backward"):
			direction += camTransform.z
			isBackward = true
			
		# Wenn nach links 'move_left'
		if Input.is_action_pressed("move_left"):
			direction -= camTransform.x
		# Wenn nach rechts 'move_right'
		if Input.is_action_pressed("move_right"):
			direction += camTransform.x
		
		# Richtung Normalisieren
		direction = direction.normalized()


#Game Process
func _process(delta):
	# interaktion prüfen
	checkInteract()

# Physic Process
func _physics_process(delta):
	# nur Wenn Bewegung erlaubt
	if isMove:
		# Kopf bewegen
		move_head(delta)
	
		# Wenn im Flugmodus
		if isFlying:
			# fliegen
			fly(delta)
		else:
			# gehen
			walk(delta)


#Bewegung aktivieren
func start_move():
	# Maus verstecken
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# Bewegung aktivieren
	isMove = true

#Bewegung deaktivieren
func stop_move():
	# Maus verstecken
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# Bewegung deaktivieren
	isMove = false

# Kopf Bewegung
func move_head(delta):
	# nur wenn eine MausBewegung
	if mouse_relative.length() > 0 :
		# Mit Maus Sensibilität multiplizieren
		mouse_relative =  mouse_relative * mouse_sensivity
		# mouse_relative = mouse_relative.linear_interpolate(mouse_relative * mouse_sensivity, delta)
		
		# Kopf (horizontal) um die Mausbeweg (von Grad in Radians umwandeln)
		Kopf.rotate_y(deg2rad(-mouse_relative.x))

		# Maus (Vertical) empfindlichkeit für Kamera umkehren
		var change = -mouse_relative.y
		
		# Prüfen ob die Mausbewegung + der Kamera ausrichtung innerhalb des erlaupten sichtfeldes ist
		if change + camera_angle < 90 and change + camera_angle > -90:
			# Änderung zur Kamera Bewegung hinzufügen
			camera_angle += change
			
			#Kamera (Vertical) rotieren
			Kamera.rotate_x(deg2rad(change))

		# Maus Bewegung zurücksetzen
		mouse_relative = Vector2()	

# Fliegen
func fly(delta):
	# Zielrichtung * Flug Geschwindigkeit
	var target = direction * fly_speed

	# Linear iterpolieren für Weichere Bewegung
	velocity = velocity.linear_interpolate(target, fly_accel * delta)
	
	# Spieler bewegen
	velocity = move_and_slide(velocity)


# Stufen
func checkStair(delta):
	# Stufe prüfen Vorwärts
	if (isForeward and velocity.length() > 0 and rayStair.is_colliding()):
		var stairHigh = rayStair.get_collision_point().y - self.translation.y
		if stairHigh <= max_stair_height:
			var stair_normal = rayStair.get_collision_normal()
			var stair_angle = rad2deg(acos(stair_normal.dot(Vector3(0, 1, 0))))
			if stair_angle < max_stair_angle:
				velocity.y = stairHigh * 500 * delta

	# Stufe prüfen Rückwärts
	if (isBackward and velocity.length() > 0 and rayStairBack.is_colliding()):
		var stairHigh = rayStairBack.get_collision_point().y - self.translation.y
		if stairHigh <= max_stair_height:
			var stair_normal = rayStairBack.get_collision_normal()
			var stair_angle = rad2deg(acos(stair_normal.dot(Vector3(0, 1, 0))))
			if stair_angle < max_stair_angle:
				velocity.y = stairHigh * 500 * delta


# Gehen
func walk(delta):
	# Gravitation hinzufügen (nach unten -y)
	velocity.y -= gravity * delta
	
	# Stufen prüfen
	checkStair(delta)
		
	# bewegung für Horizontale Bewegung merken (y auf 0 setzen)
	var temp_velocity = velocity
	temp_velocity.y = 0
	
	#Geschwindigkeit prüfen
	var speed
	
	# Wenn Laufen eingeschaltet
	if Input.is_action_pressed("move_sprint"):
		# maximale Laufgeschwindigkeit
		speed = max_running_speed
	else:
		#maximale geh-Geschwindigkeit
		speed = max_speed
		
	# Gehen Ziel bestimmen
	var target = direction * speed
	
	#Beschleunigung bestimmen
	var acceleration
	
	# Wenn aktuelle Bewegung(velocity) und gewünschte Richtung(direction)
	# in die selbe Richtung (dot Produckt ist > 0)
	if direction.dot(temp_velocity) > 0:
		# Beschleunigen
		acceleration = accel
	else:
		#Abbremsen
		acceleration = deaccel

	# für sanfte Bewegung linear Interpolieren
	temp_velocity = temp_velocity.linear_interpolate(target, acceleration * delta)
	
	# Werte für bestehende Bewegungsrichtung übernehmen (ohne Gravitation überschreiben Y-Achse)
	velocity.x = temp_velocity.x
	velocity.z = temp_velocity.z
	
	# Spieler Bewegen
	# 2 Parameter (Vector3(0,1,0) gibt an in welche Richtung der Boden schaut
	# für die Prüfung ob der Spieler am Boden Steht
	velocity = move_and_slide(velocity, Vector3(0,1,0), true, 4, deg2rad(max_floor_angle))
	
	# Springen
	# Nur wenn der Spieler am Boden steht
	if is_on_floor() and Input.is_action_just_pressed("move_jump"):
		# Sprunghöhe eingeben
		velocity.y = jump_height