/mob/living/simple_animal/hostile/retaliate/saiga/update_icon()
	cut_overlays()
	..()
	if(stat != DEAD)
		if(ssaddle)
			var/mutable_appearance/saddlet = mutable_appearance(icon, "saddle-f-above", 4.3)
			add_overlay(saddlet)
			saddlet = mutable_appearance(icon, "saddle-f")
			add_overlay(saddlet)
		if(has_buckled_mobs())
			var/mutable_appearance/mounted = mutable_appearance(icon, "saiga_mounted", 4.3)
			add_overlay(mounted)

/mob/living/simple_animal/hostile/retaliate/saiga/find_food()
	..()
	var/obj/structure/vine/SV = locate(/obj/structure/vine) in loc
	if(SV)
		SV.eat(src)
		food = max(food + 30, 100)

/mob/living/simple_animal/hostile/retaliate/saiga/tamed(mob/user)
	..()
	deaggroprob = 30
	if(can_buckle)
		AddComponent(/datum/component/riding/saiga)

/mob/living/simple_animal/hostile/retaliate/saiga/UniqueAttack()
	if(istype(target, /obj/structure/vine))
		var/obj/structure/vine/SV = target
		SV.eat(src)
		food = max(food + 30, food_max + 50)
		return
	return ..()

/mob/living/simple_animal/hostile/retaliate/saiga/proc/rider_fall()
	// Сбрасываем наездника
	if(has_buckled_mobs())
		for(var/mob/living/M in buckled_mobs)
			M.visible_message("<span class='danger'>[M] is thrown from [src] as it falls!</span>", "<span class='danger'>I'm thrown off [src] as it falls!</span>")
			unbuckle_mob(M)
			M.Knockdown(15)
			M.adjustBruteLoss(25)

/mob/living/simple_animal/hostile/retaliate/saiga/proc/eat_food(obj/item/reagent_containers/food/W, mob/user)
	// получаем нутриенты
	var/total_nutrients = 0
	if(W.reagents)
		total_nutrients = W.reagents.get_reagent_amount(/datum/reagent/consumable/nutriment)
	user.visible_message("<span class='info'>[user] hand-feeds [W] to [src].</span>", "<span class='notice'>I hand-feed [W] to [src].</span>")
	playsound(loc,'sound/misc/eat.ogg', rand(30,60), TRUE)
	// увеличиваем сытость в зависимости от нутриентов
	hunger = min(hunger + (total_nutrients/4), 1000)
	qdel(W)

/mob/living/simple_animal/hostile/retaliate/saiga/proc/eat_grass(var/turf/current_turf)
	for(var/obj/structure/flora/grass/G in current_turf)
		qdel(G)
		var/hunger_gain = rand(5, 15)
		hunger = min(hunger + hunger_gain, 1000)
		playsound(loc,'sound/misc/eat.ogg', rand(30,60), TRUE)

/mob/living/simple_animal/hostile/retaliate/saiga/proc/exhausted_handler(var/end = FALSE)
	if(!end)
		icon_state = icon_exhausted
		// остонавливаем все действия
		can_act = FALSE
		stop_automated_movement = TRUE
		adjustOxyLoss(10)
		//чтобы сайга не сразу вышла из потери сознания если причиной тому послужила выносливость
		if(!exhausted && fatigue <= 0)
			fatigue -= 75
		exhausted = TRUE
	else
		exhausted = FALSE
		can_act = TRUE
		stop_automated_movement = FALSE
		icon_state = icon_living

/mob/living/simple_animal/hostile/retaliate/saiga/proc/rest_handler(var/end = FALSE)
	if(!end)
		icon_state = icon_rest
		// остонавливаем все действия
		can_act = FALSE
		stop_automated_movement = TRUE
	else
		icon_state = icon_living
		can_act = TRUE
		stop_automated_movement = FALSE

/mob/living/simple_animal/hostile/retaliate/saiga/Retaliate()
	if(!can_act)
		return FALSE
	else
		return ..()

/mob/living/simple_animal/hostile/retaliate/saiga/proc/self_heal_from_hunger()
	if(getBruteLoss() > 0)
		adjustBruteLoss(-0.25)
		hunger -= 10
	if(getFireLoss() > 0)
		adjustFireLoss(-0.2)
		hunger -= 10

/mob/living/simple_animal/hostile/retaliate/saiga/Life()
	if(stat == DEAD)
		return ..()

	self_heal_from_hunger()

	if(saigaloc == loc && !in_stall) // Проверяем осталась ли сагайка на месте
		fatigue = min(fatigue + 10, 1000)
		hunger -= (fatigue == 1000) ? 0.5 : 1
		var/turf/current_turf = get_turf(src)
		var/rand_time = rand(0, 2.5) + 0.5 // Случайное время отдыха
		if(locate(/obj/structure/flora/grass) in current_turf) // проверяем есть ли трава и едим ее
			if(do_after(src, rand_time SECONDS, src))
				eat_grass(current_turf)

	saigaloc = loc // Сохраняем текущее местоположение сагайки

		// Теряет сознание
	if(fatigue <= 0 || hunger <= 0)
		exhausted_handler()
	else
		exhausted_handler(TRUE)
		// Отдыхает
	if(hunger < 100)
		if(!exhausted)
			rest_handler()
	else
		if(!exhausted)
			rest_handler(TRUE)



	return ..()

/mob/living/simple_animal/hostile/retaliate/saiga/attackby(obj/item/W, mob/user, params)
	if(istype(W, /obj/item/reagent_containers/food))
		if(is_type_in_list(W, blocked_food_type))
			visible_message(span_notice("[src] turns its head away from [W]."))
		else
			user.visible_message(span_info("[user] tries to feed [W] to [src]."), span_notice("I try to feed [W] to [src]."))
			if(do_after(user, 2 SECONDS, src))
				eat_food(W, user)
	. = ..()

/mob/living/simple_animal/hostile/retaliate/saiga/Hear(message, atom/movable/speaker, datum/language/message_language, raw_message, radio_freq, list/spans, message_mode, original_message)
	. = ..()
	if(!have_name)
		if(message_mode == MODE_WHISPER)
			if(speaker in buckled_mobs)
				var/new_name = trim(copytext(original_message, 2))

				// Проверяем список запрещённых имён (без учёта регистра и пробелов)
				var/cleaned_new_name = lowertext(trim(new_name))
				var/blocked = FALSE
				for(var/bad_name in blocked_names)
					if(cleaned_new_name == lowertext(trim(bad_name)))
						visible_message(span_warning("[src] refuses this name!"))
						blocked = TRUE
				// Устанавливаем новое имя
				if(!blocked)
					var/old_name = name
					name = new_name
					real_name = new_name
					have_name = TRUE
					visible_message(span_notice("[speaker] whispers something to [old_name], who will now be known as [new_name]."))

/mob/living/simple_animal/hostile/retaliate/saiga/death(gibbed)
	rider_fall()
	..()

/mob/living/simple_animal/hostile/retaliate/saiga
	icon = 'icons/roguetown/mob/monster/saiga.dmi'
	name = "saiga"
	desc = "Proud beasts of burden, warmounts, and symbols of luxury alike. Especially sacred to the steppe people of the Northeast Regions."
	icon_state = "saiga"
	icon_living = "saiga"
	icon_dead = "saiga_dead"
	icon_gib = "saiga_gib"
	icon_rest = "saiga_dead"
	icon_exhausted = "saiga_dead"
	pixel_x = -8

	animal_species = /mob/living/simple_animal/hostile/retaliate/saigabuck
	faction = list("saiga")
	gender = FEMALE
	footstep_type = FOOTSTEP_MOB_SHOE
	emote_see = list("looks around.", "chews some leaves.")
	move_to_delay = 7

	botched_butcher_results = list(/obj/item/reagent_containers/food/snacks/meat/steak = 1,
						/obj/item/natural/hide = 1,
						/obj/item/alch/bone = 1)
	butcher_results = list(/obj/item/reagent_containers/food/snacks/meat/steak = 3,
						/obj/item/reagent_containers/food/snacks/fat = 1,
						/obj/item/natural/hide = 2,
						/obj/item/alch/sinew = 2,
						/obj/item/alch/bone = 1)
	perfect_butcher_results = list(/obj/item/reagent_containers/food/snacks/meat/steak = 4,
						/obj/item/reagent_containers/food/snacks/fat = 1,
						/obj/item/natural/hide = 4,
						/obj/item/alch/sinew = 2,
						/obj/item/alch/bone = 1,
						/obj/item/natural/head/saiga = 1)

	health = FEMALE_SAIGA_HEALTH
	maxHealth = FEMALE_SAIGA_HEALTH
	food_type = list(/obj/item/reagent_containers/food/snacks/produce/grain/wheat,
					/obj/item/reagent_containers/food/snacks/produce/grain/oat,
					/obj/item/reagent_containers/food/snacks/produce/fruit/jacksberry,
					/obj/item/reagent_containers/food/snacks/produce/fruit/apple)
	var/blocked_food_type = list() 	// Список запрещенной еды для сайги
	tame_chance = 25
	bonus_tame_chance = 15
	pooptype = /obj/item/natural/poo/horse

	base_intents = list(/datum/intent/simple/headbutt)
	attack_sound = list('sound/vo/mobs/saiga/attack (1).ogg','sound/vo/mobs/saiga/attack (2).ogg')
	attack_verb_continuous = "headbutts"
	attack_verb_simple = "headbutt"
	melee_damage_lower = 10
	melee_damage_upper = 20
	retreat_distance = 10
	minimum_distance = 10
	base_speed = 15
	base_constitution = 8
	base_strength = 9
	hunger = 1000
	fatigue = 1000
	childtype = list(/mob/living/simple_animal/hostile/retaliate/saiga/saigakid = 70,
					/mob/living/simple_animal/hostile/retaliate/saiga/saigakid/boy = 30)
	can_buckle = TRUE
	buckle_lying = FALSE
	can_saddle = TRUE
	aggressive = TRUE
	var/in_stall = FALSE // флаг, что сагайка в стойле
	var/exhausted = FALSE
	var/have_name = FALSE //Нельзя дать сайге имя дважды
	remains_type = /obj/effect/decal/remains/saiga
	var/saigaloc
	var/list/blocked_names = list("Хуй", "Joster", "joster") // лист запрещенных имен для сайги

/obj/effect/decal/remains/saiga
	name = "remains"
	gender = PLURAL
	icon_state = "skele"
	icon = 'icons/roguetown/mob/monster/saiga.dmi'

/mob/living/simple_animal/hostile/retaliate/saiga/Initialize()
	. = ..()
	if(tame)
		tamed(owner)
	ADD_TRAIT(src, TRAIT_IGNOREDAMAGESLOWDOWN, TRAIT_GENERIC)

/mob/living/simple_animal/hostile/retaliate/saiga/get_sound(input)
	switch(input)
		if("aggro")
			return pick('sound/vo/mobs/saiga/attack (1).ogg','sound/vo/mobs/saiga/attack (2).ogg')
		if("pain")
			return pick('sound/vo/mobs/saiga/pain (1).ogg','sound/vo/mobs/saiga/pain (2).ogg','sound/vo/mobs/saiga/pain (3).ogg')
		if("death")
			return pick('sound/vo/mobs/saiga/death (1).ogg','sound/vo/mobs/saiga/death (2).ogg')
		if("idle")
			return pick('sound/vo/mobs/saiga/idle (1).ogg','sound/vo/mobs/saiga/idle (2).ogg','sound/vo/mobs/saiga/idle (3).ogg','sound/vo/mobs/saiga/idle (4).ogg','sound/vo/mobs/saiga/idle (5).ogg','sound/vo/mobs/saiga/idle (6).ogg','sound/vo/mobs/saiga/idle (7).ogg')


/mob/living/simple_animal/hostile/retaliate/saiga/simple_limb_hit(zone)
	if(!zone)
		return ""
	switch(zone)
		if(BODY_ZONE_PRECISE_R_EYE)
			return "head"
		if(BODY_ZONE_PRECISE_L_EYE)
			return "head"
		if(BODY_ZONE_PRECISE_NOSE)
			return "snout"
		if(BODY_ZONE_PRECISE_MOUTH)
			return "snout"
		if(BODY_ZONE_PRECISE_SKULL)
			return "head"
		if(BODY_ZONE_PRECISE_EARS)
			return "head"
		if(BODY_ZONE_PRECISE_NECK)
			return "neck"
		if(BODY_ZONE_PRECISE_L_HAND)
			return "foreleg"
		if(BODY_ZONE_PRECISE_R_HAND)
			return "foreleg"
		if(BODY_ZONE_PRECISE_L_FOOT)
			return "leg"
		if(BODY_ZONE_PRECISE_R_FOOT)
			return "leg"
		if(BODY_ZONE_PRECISE_STOMACH)
			return "stomach"
		if(BODY_ZONE_HEAD)
			return "head"
		if(BODY_ZONE_R_LEG)
			return "leg"
		if(BODY_ZONE_L_LEG)
			return "leg"
		if(BODY_ZONE_R_ARM)
			return "foreleg"
		if(BODY_ZONE_L_ARM)
			return "foreleg"

	return ..()

/mob/living/simple_animal/hostile/retaliate/saigabuck
	icon = 'icons/roguetown/mob/monster/saiga.dmi'
	name = "saigabuck"
	icon_state = "buck"
	icon_living = "buck"
	icon_dead = "buck_dead"
	icon_gib = "buck_gib"
	icon_rest = "buck_dead"
	icon_exhausted = "buck_dead"
	pixel_x = -8

	faction = list("saiga")
	footstep_type = FOOTSTEP_MOB_SHOE
	emote_see = list("stares.")
	turns_per_move = 3

	botched_butcher_results = list(/obj/item/reagent_containers/food/snacks/meat/steak = 1,
						/obj/item/reagent_containers/food/snacks/fat = 1,
						/obj/item/natural/hide = 1,
						/obj/item/alch/bone = 1)
	butcher_results = list(/obj/item/reagent_containers/food/snacks/meat/steak = 2,
						/obj/item/reagent_containers/food/snacks/fat = 1,
						/obj/item/natural/hide = 3,
						/obj/item/alch/sinew = 2,
						/obj/item/alch/bone = 1)
	perfect_butcher_results = list(/obj/item/reagent_containers/food/snacks/meat/steak = 3,
						/obj/item/reagent_containers/food/snacks/fat = 1,
						/obj/item/natural/hide = 5,
						/obj/item/alch/sinew = 2,
						/obj/item/alch/bone = 1)

	health = MALE_SAIGA_HEALTH
	maxHealth = MALE_SAIGA_HEALTH
	food_type = list(/obj/item/reagent_containers/food/snacks/produce/grain/wheat,
					/obj/item/reagent_containers/food/snacks/produce/grain/oat,
					/obj/item/reagent_containers/food/snacks/produce/fruit/jacksberry,
					/obj/item/reagent_containers/food/snacks/produce/fruit/apple)
	pooptype = /obj/item/natural/poo/horse

	base_intents = list(/datum/intent/simple/headbutt)
	attack_sound = list('sound/vo/mobs/saiga/attack (1).ogg','sound/vo/mobs/saiga/attack (2).ogg')
	attack_verb_continuous = "headbutts"
	attack_verb_simple = "headbutt"
	melee_damage_lower = 15
	melee_damage_upper = 20
	environment_smash = ENVIRONMENT_SMASH_NONE
	retreat_distance = 0
	minimum_distance = 0
	retreat_health = 0.3
	base_constitution = 15
	base_strength = 11
	base_speed = 12

	can_buckle = TRUE
	buckle_lying = 0
	can_saddle = TRUE
	tame_chance = 25
	bonus_tame_chance = 15
	aggressive = TRUE
	remains_type = /obj/effect/decal/remains/saiga
	var/in_stall = FALSE // флаг, что сагайка в стойле
	var/exhausted = FALSE
	var/have_name = FALSE //Нельзя дать сайге имя дважды
	var/saigaloc
	var/list/blocked_names = list() // лист запрещенных имен для сайги
	var/blocked_food_type = list() // Список запрещенной еды для сайги

/mob/living/simple_animal/hostile/retaliate/saigabuck/update_icon()
	cut_overlays()
	..()
	if(stat != DEAD)
		if(ssaddle)
			var/mutable_appearance/saddlet = mutable_appearance(icon, "saddle-above", 4.3)
			add_overlay(saddlet)
			saddlet = mutable_appearance(icon, "saddle")
			add_overlay(saddlet)
		if(has_buckled_mobs())
			var/mutable_appearance/mounted = mutable_appearance(icon, "buck_mounted", 4.3)
			add_overlay(mounted)


/mob/living/simple_animal/hostile/retaliate/saigabuck/get_sound(input)
	switch(input)
		if("aggro")
			return pick('sound/vo/mobs/saiga/attack (1).ogg','sound/vo/mobs/saiga/attack (2).ogg')
		if("pain")
			return pick('sound/vo/mobs/saiga/pain (1).ogg','sound/vo/mobs/saiga/pain (2).ogg','sound/vo/mobs/saiga/pain (3).ogg')
		if("death")
			return pick('sound/vo/mobs/saiga/death (1).ogg','sound/vo/mobs/saiga/death (2).ogg')
		if("idle")
			return pick('sound/vo/mobs/saiga/idle (1).ogg','sound/vo/mobs/saiga/idle (2).ogg','sound/vo/mobs/saiga/idle (3).ogg','sound/vo/mobs/saiga/idle (4).ogg','sound/vo/mobs/saiga/idle (5).ogg','sound/vo/mobs/saiga/idle (6).ogg','sound/vo/mobs/saiga/idle (7).ogg')

/mob/living/simple_animal/hostile/retaliate/saigabuck/Initialize()
	. = ..()
	if(tame)
		tamed(owner)
	ADD_TRAIT(src, TRAIT_IGNOREDAMAGESLOWDOWN, TRAIT_GENERIC)

/mob/living/simple_animal/hostile/retaliate/saigabuck/taunted(mob/user)
	emote("aggro")
	Retaliate()
	GiveTarget(user)
	return


/mob/living/simple_animal/hostile/retaliate/saigabuck/tamed(mob/user)
	..()
	deaggroprob = 20
	if(can_buckle)
		AddComponent(/datum/component/riding/saiga)

/mob/living/simple_animal/hostile/retaliate/saigabuck/eat_plants()
	//..()
	var/obj/structure/vine/SV = locate(/obj/structure/vine) in loc
	if(SV)
		SV.eat(src)
		food = max(food + 30, 100)


/mob/living/simple_animal/hostile/retaliate/saigabuck/simple_limb_hit(zone)
	if(!zone)
		return ""
	switch(zone)
		if(BODY_ZONE_PRECISE_R_EYE)
			return "head"
		if(BODY_ZONE_PRECISE_L_EYE)
			return "head"
		if(BODY_ZONE_PRECISE_NOSE)
			return "snout"
		if(BODY_ZONE_PRECISE_MOUTH)
			return "snout"
		if(BODY_ZONE_PRECISE_SKULL)
			return "head"
		if(BODY_ZONE_PRECISE_EARS)
			return "head"
		if(BODY_ZONE_PRECISE_NECK)
			return "neck"
		if(BODY_ZONE_PRECISE_L_HAND)
			return "foreleg"
		if(BODY_ZONE_PRECISE_R_HAND)
			return "foreleg"
		if(BODY_ZONE_PRECISE_L_FOOT)
			return "leg"
		if(BODY_ZONE_PRECISE_R_FOOT)
			return "leg"
		if(BODY_ZONE_PRECISE_STOMACH)
			return "stomach"
		if(BODY_ZONE_HEAD)
			return "head"
		if(BODY_ZONE_R_LEG)
			return "leg"
		if(BODY_ZONE_L_LEG)
			return "leg"
		if(BODY_ZONE_R_ARM)
			return "foreleg"
		if(BODY_ZONE_L_ARM)
			return "foreleg"
	return ..()


/mob/living/simple_animal/hostile/retaliate/saiga/saigakid
	icon = 'icons/roguetown/mob/monster/saiga.dmi'
	name = "saiga"
	icon_state = "saigakid"
	icon_living = "saigakid"
	icon_dead = "saigakid_dead"
	icon_gib = "saigakid_gib"

	animal_species = null
	gender = FEMALE
	pass_flags = PASSTABLE | PASSMOB
	mob_size = MOB_SIZE_SMALL

	botched_butcher_results = list(/obj/item/reagent_containers/food/snacks/meat/mince/beef = 1)
	butcher_results = list(/obj/item/reagent_containers/food/snacks/meat/steak = 1)
	perfect_butcher_results = list(/obj/item/reagent_containers/food/snacks/meat/steak = 1,
								/obj/item/natural/hide = 1)

	health = CALF_HEALTH
	maxHealth = CALF_HEALTH

	base_intents = list(/datum/intent/simple/headbutt)
	melee_damage_lower = 1
	melee_damage_upper = 6

	base_constitution = 5
	base_strength = 5
	base_speed = 5
	defprob = 50
	pixel_x = -16
	adult_growth = /mob/living/simple_animal/hostile/retaliate/saiga
	tame = TRUE
	can_buckle = FALSE
	aggressive = TRUE

/mob/living/simple_animal/hostile/retaliate/saiga/saigakid/boy
	icon_state = "saigaboy"
	icon_living = "saigaboy"
	icon_dead = "saigaboy_dead"
	icon_gib = "saigaboy_gib"

	gender = MALE

	health = CALF_HEALTH
	maxHealth = CALF_HEALTH

	adult_growth = /mob/living/simple_animal/hostile/retaliate/saigabuck

/mob/living/simple_animal/hostile/retaliate/saiga/tame
	tame = TRUE

/mob/living/simple_animal/hostile/retaliate/saigabuck/tame
	tame = TRUE

/mob/living/simple_animal/hostile/retaliate/saigabuck/tame/saddled/Initialize()
	. = ..()
	var/obj/item/natural/saddle/S = new(src)
	ssaddle = S
	update_icon()

/mob/living/simple_animal/hostile/retaliate/saiga/tame/saddled/Initialize()
	. = ..()
	var/obj/item/natural/saddle/S = new(src)
	ssaddle = S
	update_icon()

/*
 Все тоже самое что и для сайги, но для сгайбака
*/



/mob/living/simple_animal/hostile/retaliate/saigabuck/proc/rider_fall()
	// Сбрасываем наездника
	if(has_buckled_mobs())
		for(var/mob/living/M in buckled_mobs)
			M.visible_message("<span class='danger'>[M] is thrown from [src] as it falls!</span>", "<span class='danger'>I'm thrown off [src] as it falls!</span>")
			unbuckle_mob(M)
			M.Knockdown(15)
			M.adjustBruteLoss(25)

/mob/living/simple_animal/hostile/retaliate/saigabuck/proc/eat_food(obj/item/reagent_containers/food/W, mob/user)
	// получаем нутриенты
	var/total_nutrients = 0
	if(W.reagents)
		total_nutrients = W.reagents.get_reagent_amount(/datum/reagent/consumable/nutriment)
	user.visible_message("<span class='info'>[user] hand-feeds [W] to [src].</span>", "<span class='notice'>I hand-feed [W] to [src].</span>")
	playsound(loc,'sound/misc/eat.ogg', rand(30,60), TRUE)
	// увеличиваем сытость в зависимости от нутриентов
	hunger = min(hunger + (total_nutrients/4), 1000)
	qdel(W)

/mob/living/simple_animal/hostile/retaliate/saigabuck/proc/eat_grass(var/turf/current_turf)
	for(var/obj/structure/flora/grass/G in current_turf)
		qdel(G)
		var/hunger_gain = rand(5, 15)
		hunger = min(hunger + hunger_gain, 1000)
		playsound(loc,'sound/misc/eat.ogg', rand(30,60), TRUE)

/mob/living/simple_animal/hostile/retaliate/saigabuck/proc/exhausted_handler(var/end = FALSE)
	if(!end)
		icon_state = icon_exhausted
		// остонавливаем все действия
		can_act = FALSE
		stop_automated_movement = TRUE
		adjustOxyLoss(10)
		//чтобы сайга не сразу вышла из потери сознания если причиной тому послужила выносливость
		if(!exhausted && fatigue <= 0)
			fatigue -= 75
		exhausted = TRUE
	else
		exhausted = FALSE
		can_act = TRUE
		stop_automated_movement = FALSE
		icon_state = icon_living

/mob/living/simple_animal/hostile/retaliate/saigabuck/proc/rest_handler(var/end = FALSE)
	if(!end)
		icon_state = icon_rest
		// остонавливаем все действия
		can_act = FALSE
		stop_automated_movement = TRUE
	else
		icon_state = icon_living
		can_act = TRUE
		stop_automated_movement = FALSE

/mob/living/simple_animal/hostile/retaliate/saigabuck/Retaliate()
	if(!can_act)
		return FALSE
	else
		return ..()

/mob/living/simple_animal/hostile/retaliate/saigabuck/proc/self_heal_from_hunger()
	if(getBruteLoss() > 0)
		adjustBruteLoss(-0.25)
		hunger -= 10
	if(getFireLoss() > 0)
		adjustFireLoss(-0.2)
		hunger -= 10

/mob/living/simple_animal/hostile/retaliate/saigabuck/Life()
	if(stat == DEAD)
		return ..()

	self_heal_from_hunger()

	if(saigaloc == loc && !in_stall) // Проверяем осталась ли сагайка на месте
		fatigue = min(fatigue + 10, 1000)
		hunger -= (fatigue == 1000) ? 0.5 : 1
		var/turf/current_turf = get_turf(src)
		var/rand_time = rand(0, 2.5) + 0.5 // Случайное время отдыха
		if(locate(/obj/structure/flora/grass) in current_turf) // проверяем есть ли трава и едим ее
			if(do_after(src, rand_time SECONDS, src))
				eat_grass(current_turf)

	saigaloc = loc // Сохраняем текущее местоположение сагайки

		// Теряет сознание
	if(fatigue <= 0 || hunger <= 0)
		exhausted_handler()
	else
		exhausted_handler(TRUE)
		// Отдыхает
	if(hunger < 100)
		if(!exhausted)
			rest_handler()
	else
		if(!exhausted)
			rest_handler(TRUE)



	return ..()

/mob/living/simple_animal/hostile/retaliate/saigabuck/attackby(obj/item/W, mob/user, params)
	if(istype(W, /obj/item/reagent_containers/food))
		if(is_type_in_list(W, blocked_food_type))
			visible_message(span_notice("[src] turns its head away from [W]."))
		else
			user.visible_message(span_info("[user] tries to feed [W] to [src]."), span_notice("I try to feed [W] to [src]."))
			if(do_after(user, 2 SECONDS, src))
				eat_food(W, user)
	. = ..()

/mob/living/simple_animal/hostile/retaliate/saigabuck/Hear(message, atom/movable/speaker, datum/language/message_language, raw_message, radio_freq, list/spans, message_mode, original_message)
	. = ..()
	if(!have_name)
		if(message_mode == MODE_WHISPER)
			if(speaker in buckled_mobs)
				var/new_name = trim(copytext(original_message, 2))

				// Проверяем список запрещённых имён (без учёта регистра и пробелов)
				var/cleaned_new_name = lowertext(trim(new_name))
				var/blocked = FALSE
				for(var/bad_name in blocked_names)
					if(cleaned_new_name == lowertext(trim(bad_name)))
						visible_message(span_warning("[src] refuses this name!"))
						blocked = TRUE
				// Устанавливаем новое имя
				if(!blocked)
					var/old_name = name
					name = new_name
					real_name = new_name
					have_name = TRUE
					visible_message(span_notice("[speaker] whispers something to [old_name], who will now be known as [new_name]."))

/mob/living/simple_animal/hostile/retaliate/saigabuck/death(gibbed)
	rider_fall()
	..()
