[[ -n "${_NPC_SH_INCLUDED:-}" ]] && return
_NPC_SH_INCLUDED=1

source object.sh
source ui.sh
source item.sh
source player.sh

if [[ -z "${NPC_REGISTRY_LOADED:-}" ]]; then
  declare -ag NPC_REGISTRY=()
  NPC_REGISTRY_LOADED=1
fi

register_npc() {
   local npc_ref=$1
   NPC_REGISTRY+=("$npc_ref")
}

unregister_npc() {
  local npc_ref=$1
  local new_registry=()
  local npc
  for npc in "${NPC_REGISTRY[@]}"; do
    if [[ "$npc" != "$npc_ref" ]]; then
      new_registry+=("$npc")
    fi
  done
  NPC_REGISTRY=("${new_registry[@]}")
}

get_npc_obj_ref() {
  local prefix=$1
  local used_ids=()
  local npc
  for npc in "${NPC_REGISTRY[@]}"; do
    if [[ "$npc" =~ ^${prefix}npc([0-9]+)$ ]]; then
      used_ids+=("${BASH_REMATCH[1]}")
    fi
  done
  local id=1
  while :; do
    local found=0
    for used in "${used_ids[@]}"; do
      if [[ 10#$used -eq "$id" ]]; then
        found=1
      fi
    done
    [[ $found -eq 0 ]] && break
    ((id++))
  done
  local npc_ref
  printf -v npc_ref "%snpc%03d" "$prefix" "$id"
  unset "$npc_ref"
  declare -gA "$npc_ref"
  assigned_npc_ref="$npc_ref"
}

gen_monster_name() {
  local perk=$1
  local prefixes=("Dark" "Rotten" "Wild" "Ancient" "Feral" "Savage" "Corrupted" "Vile" "Brutal" "Forsaken")
  local bases=("Wolf" "Ghoul" "Rat" "Bat" "Spider" "Serpent" "Goblin" "Wraith" "Beast" "Skeleton")
  local suffixes=("of Pain" "of Shadows" "of Doom" "of Agony" "of Night" "of the Deep" "of Curses" "of Chaos" "of Blood" "of Death")

  local prefix base suffix name

  case "$perk" in
    0) # normal
      base=${bases[$((RANDOM % ${#bases[@]}))]}
      name="$base"
      ;;
    1) # tough
      prefix=${prefixes[$((RANDOM % ${#prefixes[@]}))]}
      base=${bases[$((RANDOM % ${#bases[@]}))]}
      name="$prefix $base"
      ;;
    2) # elite
      prefix=${prefixes[$((RANDOM % ${#prefixes[@]}))]}
      base=${bases[$((RANDOM % ${#bases[@]}))]}
      suffix=${suffixes[$((RANDOM % ${#suffixes[@]}))]}
      name="$prefix $base $suffix"
      ;;
    3) # boss
      local bosses=("Azrak the Devourer" "Morgul the Eternal" "Karthos, Lord of Ruin" "Xynathar the Fallen" "Vorgrath the Undying")
      name=${bosses[$((RANDOM % ${#bosses[@]}))]}
      ;;
    *)
      name="Unknown Creature"
      ;;
  esac

  echo "$name"
}

gen_npc_name() {
    local first_names=(
        "Arin" "Borin" "Cedra" "Darian" "Elira" "Farin" "Gorim" "Helia"
        "Isen" "Jarik" "Kira" "Lorin" "Mira" "Noran" "Orin" "Pela"
        "Quen" "Risa" "Serin" "Tara" "Ulric" "Vera" "Warin" "Xena"
        "Yorin" "Zira"
    )
    local last_prefix=(
        "Ash" "Bram" "Crow" "Dusk" "Elk" "Frost" "Gray" "Iron" "Oak"
        "Raven" "Storm" "Thorn" "Winter" "Wolf" "Stone" "Moon"
    )
    local last_suffix=(
        "wood" "ridge" "fall" "brook" "heart" "vale" "field" "forge"
        "born" "keep" "watch" "mark" "helm" "song" "ward" "blade"
    )
    local fn="${first_names[RANDOM % ${#first_names[@]}]}"
    local lp="${last_prefix[RANDOM % ${#last_prefix[@]}]}"
    local ls="${last_suffix[RANDOM % ${#last_suffix[@]}]}"
    echo "$fn $lp$ls"
}

create_npc_icon() {
    local npc_ref="$1"
    local subtype
    subtype=$(obj_get "$npc_ref" "subtype")

    case "$subtype" in
        1)  # merchant
            obj_set "$npc_ref" "icon" "S"
            obj_set "$npc_ref" "fg_color" "33"
            obj_set "$npc_ref" "bg_color" "40"
            ;;
        2)  # healer
            obj_set "$npc_ref" "icon" "H"
            obj_set "$npc_ref" "fg_color" "31"
            obj_set "$npc_ref" "bg_color" "40"
            ;;
        3)  # dummy (training target)
            obj_set "$npc_ref" "icon" "C"
            obj_set "$npc_ref" "fg_color" "36"
            obj_set "$npc_ref" "bg_color" "40"
            ;;
        4)  # innkeeper
            obj_set "$npc_ref" "icon" "I"
            obj_set "$npc_ref" "fg_color" "36"
            obj_set "$npc_ref" "bg_color" "40"
            ;;
        5)  # quest giver
            obj_set "$npc_ref" "icon" "Q"
            obj_set "$npc_ref" "fg_color" "32"
            obj_set "$npc_ref" "bg_color" "40"
            ;;
        6)  # main quest giver
            obj_set "$npc_ref" "icon" "Q"
            obj_set "$npc_ref" "fg_color" "33"
            obj_set "$npc_ref" "bg_color" "40"
            ;;
        *)
            # fallback
            obj_set "$npc_ref" "icon" "?"
            obj_set "$npc_ref" "fg_color" "37"
            obj_set "$npc_ref" "bg_color" "40"
            ;;
    esac
}


create_monster_icon() {
  local npc_ref=$1
  local perk
  perk=$(obj_get "$npc_ref" "perk")
  local symbols=('€' '£' '¥' '₩' '¿' '~' '¤')
  local symbol=${symbols[$((RANDOM % ${#symbols[@]}))]}
  local bg_color
  case "$perk" in
    0)
     bg_color="40"
     ;; # normal = černé
    1)
     bg_color="44"
     ;; # tough = modré
    2)
     bg_color="43"
     ;; # elite = žluté
    3)
     bg_color="41"
     ;; # boss = červené
    *)
      bg_color="40"
     ;; # fallback
  esac
  local icon="$symbol"
  obj_set "$npc_ref" "icon" "$icon"
  obj_set "$npc_ref" "bg_color" "$bg_color"
  obj_set "$npc_ref" "fg_color" 37
}

create_random_normal_monster() {
    local npc_ref=$1
    declare -n NPC="$npc_ref"

    local l="${player_ref[level]:-1}"
    randf() { echo "$((50 + RANDOM % 50))"; }
    NPC[level]=$(( l * $(randf) / 100 ))
    (( NPC[level] < 1 )) && NPC[level]=1
    NPC[hp]=$(( 4 * l * $(randf) / 100 ))
    (( NPC[hp] < 1 )) && NPC[hp]=4
    NPC[mana]=$(( 2 * l * $(randf) / 100 ))
    NPC[defense]=$(( 2 * l * $(randf) / 100 + 1 ))
    NPC[min_damage]=$(( l * $(randf) / 100 + 2 ))
    NPC[max_damage]=$(( l * (100 + RANDOM % 50) / 100 + 2 ))
    NPC[block_rate]=$(( NPC[level] * (100 + RANDOM % 50) / 100 ))
    (( NPC[block_rate] > 50 )) && NPC[block_rate]=50
    for res in fire_resistence cold_resistence poison_resistence lightning_resistence; do
        NPC[$res]=$(( RANDOM % (l + 1) ))
        (( NPC[$res] > 25 )) && NPC[$res]=25
    done
    NPC[experience]=$(( NPC[level] * 10 ))
    NPC[perk]=0
    NPC[name]="$(gen_monster_name 0)"
    create_monster_icon "$npc_ref"
}

create_random_tough_monster() {
    local npc_ref=$1
    declare -n NPC="$npc_ref"
    declare -n P=player_ref

    local m=3  # multiplier ~1.5 (2–3 range zajišťuje vyšší výdrž tough monster)
    randf() { echo "$((50 + RANDOM % 50))"; }
    local l="${P[level]:-1}"
    NPC[level]=$(( l * $(randf) / 100 * m / 2 ))
    (( NPC[level] < 1 )) && NPC[level]=1
    NPC[hp]=$(( 6 * l * $(randf) / 100 * m / 2 ))
    (( NPC[hp] < 1 )) && NPC[hp]=1
    NPC[mana]=$(( 3 * l * $(randf) / 100 * m / 2 ))
    for s in strength vitality energy dexterity; do
        NPC[$s]=$(( l * $(randf) / 100 * m / 2 ))
    done
    NPC[defense]=$(( 3 * l * $(randf) / 100 * m / 2 + 1 ))
    NPC[min_damage]=$(( l * (100 + RANDOM % 50) / 100 * m / 2 + 1 ))
    NPC[max_damage]=$(( l * (150 + RANDOM % 50) / 100 * m / 2 + 1 ))
    NPC[block_rate]=$(( NPC[level] * (100 + RANDOM % 50) / 100 * m / 2 ))
    (( NPC[block_rate] > 65 )) && NPC[block_rate]=65
    for res in fire_resistence cold_resistence poison_resistence lightning_resistence; do
        NPC[$res]=$(( RANDOM % (l * m + 1) ))
        (( NPC[$res] > 40 )) && NPC[$res]=40
    done
    NPC[experience]=$(( NPC[level] * 15 * m / 2 ))
    NPC[perk]=1
    NPC[name]="$(gen_monster_name 1)"
    create_monster_icon "$npc_ref"
}

create_random_elite_monster() {
    local npc_ref=$1
    create_random_tough_monster "$npc_ref"
    declare -n NPC="$npc_ref"
    declare -n P=player_ref
    NPC[perk]=2
    local l="${P[level]:-1}"
    (( l < 1 )) && l=1
    local elements=("fire" "cold" "poison" "lightning")
    local element=${elements[$(( RANDOM % 4 ))]}
    randf() { echo "$((50 + RANDOM % 50))"; }
    case "$element" in
        poison)
            NPC[poison_damage]=$(( l * (100 + RANDOM % 100) / 100 ))
            NPC[poison_damage_time]=$(( l * (50 + RANDOM % 100) / 100 + 1 ))
            ;;
        *)
            NPC["${element}_damage_min"]=$(( l * $(randf) / 100 ))
            NPC["${element}_damage_max"]=$(( l * $(randf) / 100 + l / 2 + 1 ))
            ;;
    esac
    NPC[experience]=$(( NPC[level] * 20 ))
    NPC[name]="$(gen_monster_name 2)"
    create_monster_icon "$npc_ref"
}

create_random_boss_monster() {
    local npc_ref=$1
    create_random_tough_monster "$npc_ref"
    declare -n NPC="$npc_ref"
    declare -n P=player_ref
    NPC[perk]=3
    local l="${P[level]:-1}"
    (( l < 1 )) && l=1
    local multiplier=15  # 1.5x, vyhneme se floatům
    local base=10        # děleno 10 na konci
    for stat in hp mana strength vitality energy dexterity defense min_damage max_damage; do
        NPC["$stat"]=$(( (NPC["$stat"] * multiplier) / base ))
    done
    randf() { echo "$((50 + RANDOM % 50))"; }
    local elements=("fire" "cold" "poison" "lightning")
    local e1=${elements[$((RANDOM % 4))]}
    local e2=${elements[$((RANDOM % 4))]}
    while [[ "$e2" == "$e1" ]]; do e2=${elements[$((RANDOM % 4))]}; done
    for e in "$e1" "$e2"; do
        case "$e" in
            poison)
                NPC[poison_damage]=$(( l * $(randf) / 100 + l / 2 + 2 ))
                NPC[poison_damage_time]=$(( l * $(randf) / 100 + 2 ))
                ;;
            *)
                NPC["${e}_damage_min"]=$(( l * $(randf) / 100 + l / 3 + 1 ))
                NPC["${e}_damage_max"]=$(( l * $(randf) / 100 + l / 2 + 3 ))
                ;;
        esac
    done
    NPC[experience]=$(( NPC[level] * 30 ))
    NPC[name]="$(gen_monster_name 3)"
    create_monster_icon "$npc_ref"
}

create_random_monster() {
  local npc_ref
  local map=$(get_player_stat "map")
  get_npc_obj_ref "$map"
  npc_ref="$assigned_npc_ref"
  register_npc "$npc_ref"
  obj_set "$npc_ref" "type" 1
  obj_set "$npc_ref" "subtype" 0
  local rnd=$((RANDOM % 100))
  local perk
   if ((rnd < 85)); then
    perk=0 # normal
    create_random_normal_monster "$npc_ref"
  elif ((rnd < 95)); then
    perk=1 # tough
    create_random_tough_monster "$npc_ref"
  elif ((rnd < 99)); then
    perk=2 # elite
    create_random_elite_monster "$npc_ref"
  else
    perk=3 # boss
    create_random_boss_monster "$npc_ref"
  fi
  #register_npc "$npc_ref"
  created_monster="$npc_ref"
}

create_random_monster_no_reg() {
  local npc_ref=$1
  obj_set "$npc_ref" "type" 1
  obj_set "$npc_ref" "subtype" 0
  local rnd=$((RANDOM % 100))
  local perk
  if ((rnd < 85)); then
    perk=0 # normal
    create_random_normal_monster "$npc_ref"
  elif ((rnd < 95)); then
    perk=1 # tough
    create_random_tough_monster "$npc_ref"
  elif ((rnd < 99)); then
    perk=2 # elite
    create_random_elite_monster "$npc_ref"
  else
    perk=3 # boss
    create_random_boss_monster "$npc_ref"
  fi
  local name
  name=$(gen_monster_name "$perk")
  obj_set "$npc_ref" "name" "$name"
  create_monster_icon "$npc_ref"
}

# Funkce pro spočtení počtu monster v roji podle levelu hráče
calculate_swarm_count() {
  local level=$1
  local rnd=$((RANDOM % 100 + 1))
  local count=1

  if ((level <= 1)); then
    if ((rnd <= 80)); then
      count=1
    elif ((rnd <= 95)); then
      count=2
    else
      count=3
    fi
  elif ((level >= 50)); then
    if ((rnd <= 0)); then
      count=1
    elif ((rnd <= 0)); then
      count=2
    elif ((rnd <= 0)); then
      count=3
    elif ((rnd <= 0)); then
      count=4
    elif ((rnd <= 0)); then
      count=5
    elif ((rnd <= 3)); then
      count=6
    elif ((rnd <= 8)); then
      count=7
    elif ((rnd <= 13)); then
      count=8
    elif ((rnd <= 23)); then
      count=9
    else
      count=10
    fi
  else
    local min_count=$((1 + (level - 1) * (5 - 1) / 49)) # aproximace
    local max_count=$((3 + (level - 1) * (10 - 3) / 49))
    count=$((RANDOM % (max_count - min_count + 1) + min_count))
  fi
  echo "$count"
}

create_merchant_no_reg() {
  local npc_ref=$1
  obj_set "$npc_ref" "type" 1
  obj_set "$npc_ref" "subtype" 1
  name=$(gen_npc_name)
  obj_set "$npc_ref" "name" "$name"
  create_npc_icon "$npc_ref"
}

create_healer_no_reg() {
  local npc_ref=$1
  obj_set "$npc_ref" "type" 1
  obj_set "$npc_ref" "subtype" 2
  name=$(gen_npc_name)
  obj_set "$npc_ref" "name" "$name"
  create_npc_icon "$npc_ref"
}

is_empty_inventory() {
    local npc_ref=$1
    declare -n NPC="$npc_ref"
    for i in {1..8}; do
        local slot="inventory$i"
        local val="${NPC[$slot]}"
        [[ -n "$val" ]] && return 1  # našli jsme něco → inventář není prázdný
    done
    return 0  # nic nebylo nalezeno → prázdný inventář
}


fill_npc_inv() {
   local npc_ref=$1
   local map=$2
   local subtype=$(obj_get "$npc_ref" "subtype")
   case $subtype in
     1) #merchant
        for i in {1..8}; do
            local slot="inventory$i"
            get_item_obj_ref "$map"
            local item_ref="$assigned_item_ref"
            create_blank_object "$item_ref"
            obj_set "$item_ref" "type" 2
            register_item "$item_ref"
            obj_set "$item_ref" "in_inventory" 1
            obj_set "$item_ref" "in_npc_inv" 1
            local level=$(get_player_stat "level")
            obj_set "$item_ref" "perk" 0
            create_random_normal_item_no_gold "$level" "$item_ref"
            obj_set "$npc_ref" "$slot" "$item_ref"
            create_item_icon "$item_ref"
        done
        ;;
     2) #healer
        for i in {1..6}; do
            local slot="inventory$i"
            get_item_obj_ref "$map"
            local item_ref="$assigned_item_ref"
            create_blank_object "$item_ref"
            obj_set "$item_ref" "type" 2
            register_item "$item_ref"
            obj_set "$item_ref" "in_inventory" 1
            obj_set "$item_ref" "in_npc_inv" 1
            local level=$(get_player_stat "level")
            obj_set "$item_ref" "perk" 0
            create_random_healing_potion "$level" "$item_ref"
            obj_set "$npc_ref" "$slot" "$item_ref"
            create_item_icon "$item_ref"
        done
        for i in {7..8}; do
            local slot="inventory$i"
            get_item_obj_ref "$map"
            local item_ref="$assigned_item_ref"
            create_blank_object "$item_ref"
            obj_set "$item_ref" "type" 2
            register_item "$item_ref"
            obj_set "$item_ref" "in_inventory" 1
            obj_set "$item_ref" "in_npc_inv" 1
            obj_set "$item_ref" "perk" 0
            create_random_mana_potion "$level" "$item_ref"
            obj_set "$npc_ref" "$slot" "$item_ref"
            create_item_icon "$item_ref"
        done
        ;;
     3) #dummy
        get_item_obj_ref "$map"
        local item_ref="$assigned_item_ref"
        create_blank_object "$item_ref"
        obj_set "$item_ref" "type" 2
        register_item "$item_ref"
        obj_set "$item_ref" "in_inventory" 1
        obj_set "$item_ref" "in_npc_inv" 1
        local level=$(get_player_stat "level")
        obj_set "$item_ref" "perk" 0
        create_random_normal_item_no_gold "$level" "$item_ref"
        obj_set "$npc_ref" "inventory1" "$item_ref"
        create_item_icon "$item_ref"
        get_item_obj_ref "$map"
        local item_ref="$assigned_item_ref"
        create_blank_object "$item_ref"
        obj_set "$item_ref" "type" 2
        register_item "$item_ref"
        obj_set "$item_ref" "in_inventory" 1
        obj_set "$item_ref" "in_npc_inv" 1
        obj_set "$item_ref" "perk" 0
        create_random_food "$level" "$item_ref"
        obj_set "$npc_ref" "inventory2" "$item_ref"
        create_item_icon "$item_ref"
        ;;
    esac
}

create_civilian_no_reg() {
  local npc_ref=$1
  obj_set "$npc_ref" "type" 1
  obj_set "$npc_ref" "subtype" 3
  name=$(gen_npc_name)
  obj_set "$npc_ref" "name" "$name"
  create_npc_icon "$npc_ref"
}

create_innkeeper_no_reg() {
  local npc_ref=$1
  obj_set "$npc_ref" "type" 1
  obj_set "$npc_ref" "subtype" 4
  name=$(gen_npc_name)
  obj_set "$npc_ref" "name" "$name"
  create_npc_icon "$npc_ref"
}

iterate_over_npc_par() {
  local func_name=$1
  shift
  local npc_ref
  for npc_ref in "${NPC_REGISTRY[@]}"; do
    "$func_name" "$npc_ref" "$@" &
  done
  wait
}

iterate_over_npc() {
  local func_name=$1
  shift
  local npc_ref
  for npc_ref in "${NPC_REGISTRY[@]}"; do
    "$func_name" "$npc_ref" "$@"
  done
}

draw_npc() {
    local npc_ref=$1
    local px=$2
    local py=$3
    declare -n NPC="$npc_ref"
    local x=${NPC[x]}
    local y=${NPC[y]}
    if ! in_viewport "$x" "$y"; then
        return 0
    fi
    local vx=$(( x - px + VIEWPORT_WIDTH / 2 ))
    local vy=$(( y - py + VIEWPORT_HEIGHT / 2 ))
    local icon=${NPC[icon]}
    local bg=${NPC[bg_color]:-49}  # implicitní — transparentní pozadí pokud není definováno
    local fg=${NPC[fg_color]:-37}  # implicitní světle šedá
    printf "%s;%s;%s;%s;%s\n" "$vx" "$vy" "$icon" "$bg" "$fg"
}

draw_npcs() {
  local vx vy icon fg bg line
  local px=$PLAYER_X
  local py=$PLAYER_Y
  while IFS=';' read -r vx vy icon bg fg; do
     FRAME_BUFFER["$vx,$vy"]="\e[${bg};${fg}m${icon}\e[0m"
  done < <(iterate_over_npc_par "draw_npc" "$px" "$py")
}

npc_on_xy_helper() {
  local npc_ref=$1
  local x=$2
  local y=$3
  local npcx npcy
  npcx=$(obj_get "$npc_ref" "x")
  npcy=$(obj_get "$npc_ref" "y")
  if [[ "$x" == "$npcx" && "$y" == "$npcy" ]]; then
    echo "$npc_ref"
  fi
}

npc_on_xy() {
  local x=$1
  local y=$2
  local found
  found=$(iterate_over_npc_par "npc_on_xy_helper" "$x" "$y")
  if [[ -n "$found" ]]; then
    echo "$found" # vrací referenci NPC, které je na daných souřadnicích
  else
    echo ""
  fi
}

kill() {
  local npc_ref=$1
  if [[ "$npc_ref" == "player_ref" ]]; then
   kill_player
   return 0
  fi
  local player_exp
  local monster_exp
  player_exp=$(get_player_stat "experience")
  monster_exp=$(obj_get "$npc_ref" "experience")
  set_player_stat "experience" $((player_exp + monster_exp))
  check_level_up
  drop_loot "$npc_ref"
  unregister_npc "$npc_ref"
  destroy_object "$npc_ref"
}

attack() {
  local attacker_ref=$1
  local defender_ref=$2
  local attacker_name defender_name
  attacker_name=$(obj_get "$attacker_ref" "name")
  defender_name=$(obj_get "$defender_ref" "name")
  local attacker_min attacker_max attacker_defense attacker_block
  local attacker_fire_min attacker_fire_max attacker_cold_min attacker_cold_max
  local attacker_poison_dmg attacker_poison_time attacker_light_min attacker_light_max
  attacker_min=$(obj_get "$attacker_ref" "min_damage")
  attacker_max=$(obj_get "$attacker_ref" "max_damage")
  attacker_fire_min=$(obj_get "$attacker_ref" "fire_damage_min")
  attacker_fire_max=$(obj_get "$attacker_ref" "fire_damage_max")
  attacker_cold_min=$(obj_get "$attacker_ref" "cold_damage_min")
  attacker_cold_max=$(obj_get "$attacker_ref" "cold_damage_max")
  attacker_light_min=$(obj_get "$attacker_ref" "lightning_damage_min")
  attacker_light_max=$(obj_get "$attacker_ref" "lightning_damage_max")
  attacker_poison_dmg=$(obj_get "$attacker_ref" "poison_damage")
  attacker_poison_time=$(obj_get "$attacker_ref" "poison_damage_time")
  local base_damage=$((RANDOM % (attacker_max - attacker_min + 1) + attacker_min))
  local fire_dmg=0 cold_dmg=0 lightning_dmg=0 poison_dmg=0 poison_time=0
  ((attacker_fire_max > 0)) && fire_dmg=$((RANDOM % (attacker_fire_max - attacker_fire_min + 1) + attacker_fire_min))
  ((attacker_cold_max > 0)) && cold_dmg=$((RANDOM % (attacker_cold_max - attacker_cold_min + 1) + attacker_cold_min))
  ((attacker_light_max > 0)) && lightning_dmg=$((RANDOM % (attacker_light_max - attacker_light_min + 1) + attacker_light_min))
  ((attacker_poison_dmg > 0)) && poison_dmg=$attacker_poison_dmg && poison_time=$attacker_poison_time
  local total_defense=$(obj_get "$defender_ref" "defense")
  local total_block=$(obj_get "$defender_ref" "block_rate")
  local fire_res=$(obj_get "$defender_ref" "fire_resistence")
  local cold_res=$(obj_get "$defender_ref" "cold_resistence")
  local poison_res=$(obj_get "$defender_ref" "poison_resistence")
  local light_res=$(obj_get "$defender_ref" "lightning_resistence")
  local slots=("weapon" "shield" "helmet" "armor" "amulet" "ring")
  for slot in "${slots[@]}"; do
    local eq_ref
    eq_ref=$(obj_get "$defender_ref" "$slot")
    [[ -z "$eq_ref" ]] && continue

    ((total_defense += $(obj_get "$eq_ref" "defense")))
    ((total_block += $(obj_get "$eq_ref" "block_rate")))
    ((fire_res += $(obj_get "$eq_ref" "fire_resistence")))
    ((cold_res += $(obj_get "$eq_ref" "cold_resistence")))
    ((poison_res += $(obj_get "$eq_ref" "poison_resistence")))
    ((light_res += $(obj_get "$eq_ref" "lightning_resistence")))
  done
  ((fire_res > 85)) && fire_res=85
  ((cold_res > 85)) && cold_res=85
  ((poison_res > 85)) && poison_res=85
  ((light_res > 85)) && light_res=85
  ((total_block > 50)) && total_block=50
  local roll=$((RANDOM % 100 + 1))
  if ((roll <= total_block)); then
    print_ui "" "${defender_name} blocked the attack from ${attacker_name}!"
    return 0
  fi
  fire_dmg=$((fire_dmg - (fire_dmg * fire_res / 100)))
  cold_dmg=$((cold_dmg - (cold_dmg * cold_res / 100)))
  poison_dmg=$((poison_dmg - (poison_dmg * poison_res / 100)))
  lightning_dmg=$((lightning_dmg - (lightning_dmg * light_res / 100)))
  if ((base_damage < total_defense)); then
    base_damage=$((base_damage * base_damage / (total_defense + 1)))
  else
    base_damage=$((base_damage + (base_damage - total_defense) / 2))
  fi
  ((base_damage < 0)) && base_damage=0
  local total_damage=$((base_damage + fire_dmg + cold_dmg + lightning_dmg))
  local hp
  hp=$(obj_get "$defender_ref" "hp")
  ((hp -= total_damage))
  ((hp < 0)) && hp=0
  obj_set "$defender_ref" "hp" "$hp"
  if ((hp <= 0)); then
    print_ui "" "${defender_name} was killed by ${attacker_name}!"
    kill "$defender_ref"
    return 0
  fi
  print_ui "" "${attacker_name} hits ${defender_name} for ${total_damage} damage!"
  if ((poison_dmg > 0)); then
    obj_set "$defender_ref" "poisoned" "true"
    obj_set "$defender_ref" "poison_amount" "$poison_dmg"
    obj_set "$defender_ref" "poison_time_max" "$poison_time"
    #obj_set "$defender_ref" "poison_time" "$poison_time"
    print_ui "" "${defender_name} is poisoned for ${poison_time} turns!"
  fi
}

drive_npc_ai() {
    local npc_ref=$1
    local px=$2
    local py=$3
    declare -n NPC="$npc_ref"
    local nx="${NPC[x]}"
    local ny="${NPC[y]}"
    local dx=$((px - nx))
    local dy=$((py - ny))
    local adx=${dx#-}
    local ady=${dy#-}
    if [[ "${NPC[subtype]}" != "0" ]]; then
    return
    fi

    if ((adx > 10 || ady > 10)); then
        #printf "%s %d %d N\n" "$npc_ref" "$nx" "$ny"
        return
    fi

    if (( (adx == 1 && ady == 0) || (adx == 0 && ady == 1) )); then
        printf "%s %d %d A\n" "$npc_ref" "$nx" "$ny"
        return
    fi

    if ((adx == 1 && ady == 1)); then
        ((RANDOM & 1)) && dx=0 || dy=0
    fi

    local step_x=0 step_y=0
    ((dx > 0)) && step_x=1
    ((dx < 0)) && step_x=-1
    ((dy > 0)) && step_y=1
    ((dy < 0)) && step_y=-1

    local new_x=$((nx + step_x))
    local new_y=$((ny + step_y))

    if ! tile_is_passable "$(get_map_tile_xy "$new_x" "$new_y")"; then
        #printf "%s %d %d N\n" "$npc_ref" "$nx" "$ny"
        return
    fi

    printf "%s %d %d M\n" "$npc_ref" "$new_x" "$new_y"
}

apply_npc_ai_results() {
    local npc_ref x y action

    while IFS=' ' read -r npc_ref x y action; do
        [[ -z "$npc_ref" ]] && continue

        case "$action" in
            A)
                attack "$npc_ref" "player_ref"
                ;;

            M)
                declare -n NPC="$npc_ref"

                [[ -n $(npc_on_xy "$x" "$y") ]] && continue
                NPC[x]="$x"
                NPC[y]="$y"
                ;;

            #N)
            #    ;;
        esac
    done
}

drive_npcs() {
    local npc_ref
    local px=$PLAYER_X
    local py=$PLAYER_Y
    apply_npc_ai_results < <(
        for npc_ref in "${NPC_REGISTRY[@]}"; do
            drive_npc_ai "$npc_ref" "$px" "$py" &
        done
        wait
    )
}

monster_in_viewport() {
  local npc_ref=$1
  local subtype
  subtype=$(obj_get "$npc_ref" "subtype")
  if [[ "$subtype" -ne 0 ]]; then
    return 1
  fi
  local x y
  x=$(obj_get "$npc_ref" "x")
  y=$(obj_get "$npc_ref" "y")
  if in_viewport "$x" "$y"; then
    echo "$npc_ref"
    return 0
  else
    return 1
  fi
}

monsters_in_viewport() {
  iterate_over_npc_par "monster_in_viewport"
}

save_npc() {
  local npc_ref=$1
  local map=$(get_player_stat "map")
  obj_store "$npc_ref" "save/maps/$map.d/npcs" "$npc_ref"
}

save_npcs() {
  iterate_over_npc_par save_npc
}

load_npcs() {
  local map=$(get_player_stat "map")
  local dir="save/maps/$map.d/npcs"
  [[ ! -d "$dir" ]] && return
  shopt -s nullglob
  for file in "$dir"/*; do
    local base
    base=$(basename "$file")
    local npc_ref="$base"
    declare -g -A "$npc_ref"
    obj_load "$npc_ref" "$dir" "$base"
    register_npc "$npc_ref"
  done
  shopt -u nullglob
  rm -rf "$dir"/*
}

drive_poison_on_npc() {
    local npc_ref=$1
    declare -n NPC="$npc_ref"
    [[ "${NPC[poisoned]}" != "true" ]] && return 0
    local poison_time=${NPC[poison_time]}
    local poison_time_max=${NPC[poison_time_max]}
    local poison_amount=${NPC[poison_amount]}
    local hp=${NPC[hp]}
    ((poison_time_max <= 0)) && poison_time_max=1
    local dmg=$((poison_amount / poison_time_max))
    ((dmg <= 0)) && dmg=1
    hp=$((hp - dmg))
    ((hp < 0)) && hp=0
    NPC[hp]=$hp
    NPC[poison_time]=$((poison_time + 1))
    if [[ "$npc_ref" == "player_ref" ]]; then
        print_ui "" "You took $dmg poison damage."
    fi
    if ((hp == 0)); then
        if [[ "$npc_ref" == "player_ref" ]]; then
            print_ui "" "You have died from poison!"
            kill_player
        else
            kill "$npc_ref"
        fi
        return
    fi
    if ((NPC[poison_time] >= poison_time_max)); then
        NPC[poisoned]="false"
        NPC[poison_time]=0
        NPC[poison_time_max]=0
        NPC[poison_amount]=0
        if [[ "$npc_ref" == "player_ref" ]]; then
            print_ui "" "Poison has worn off."
        fi
    fi
}

drive_poison() {
  drive_poison_on_npc "player_ref"
  iterate_over_npc drive_poison_on_npc
}

create_swarm() {
  local player_level
  player_level=$(get_player_stat "level")
  local px py
  px=$(get_player_stat "x")
  py=$(get_player_stat "y")
  local dx dy
  local sdx sdy
  sdx=$(get_player_deltax)
  if ((sdx > 0)); then
    dx=1
  elif ((sdx < 0)); then
    dx=-1
  else
    dx=0
  fi
  sdy=$(get_player_deltay)
  if ((sdy > 0)); then
    dy=1
  elif ((sdy < 0)); then
    dy=-1
  else
    dy=0
  fi
  local distance=$((RANDOM % 6 + 5))
  local start_x=$((px + dx * distance))
  local start_y=$((py + dy * distance))
  local num_monsters
  num_monsters=$(calculate_swarm_count "$player_level")
  print_ui "" "You found a swarm of $num_monsters monsters!"
  for ((i = 0; i < num_monsters; i++)); do
    local npc_ref mx my tries=20
    create_random_monster
    npc_ref="$created_monster"
    while ((tries-- > 0)); do
      mx=$((start_x + RANDOM % 5))
      my=$((start_y + RANDOM % 5))
      if ! npc_on_xy "$mx" "$my" >/dev/null; then
        break
      fi
    done
    obj_set "$npc_ref" "x" "$mx"
    obj_set "$npc_ref" "y" "$my"
  done
}

destroy_npc() {
   local npc_ref=$1
  unregister_npc "$npc_ref"
  destroy_object "$npc_ref"
}

delete_all_npcs() {
  iterate_over_npc "destroy_npc"
}
