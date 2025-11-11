
[[ -n "${_PLAYER_SH_INCLUDED:-}" ]] && return
_PLAYER_SH_INCLUDED=1
source object.sh
source map.sh
source item.sh
source npc.sh

kill_player() {
    local hp_max
    hp_max=$(get_player_stat "hp_max")
    local mana_max
    mana_max=$(get_player_stat "mana_max")
    set_player_stat "hp" $((hp_max / 2))
    set_player_stat "mana" $((mana_max / 2))
    local safe_x
    safe_x=$(get_player_stat "safe_x")
    local safe_y
    safe_y=$(get_player_stat "safe_y")
    local safe_lastx safe_lasty
    safe_lastx=$(get_player_stat "safe_lastx")
    safe_lasty=$(get_player_stat "safe_lasty")
    set_player_stat "lastx" "$safe_lastx"
    set_player_stat "lasty" "$safe_lasty"
    set_player_stat "x" "$safe_x"
    set_player_stat "y" "$safe_y"
    set_player_stat "poisoned" "false"
    set_player_stat "poison_time" 0
    set_player_stat "poison_time_max" 0
    set_player_stat "poison_amount" 0
    PLAYER_X=$safe_x
    PLAYER_Y=$safe_y
    local safe_map
    safe_map=$(get_player_stat "safe_map")
    local safe_subtype safe_location
    safe_subtype=$(get_player_stat "safe_subtype")
    safe_location=$(get_player_stat "safe_location")
    set_player_stat "location" "$safe_location"
    change_map "$safe_map" "$safe_subtype"
    print_ui "" "You have been revived at the last safe location."
}

get_player_stat() {
  local stat=$1
  echo $(obj_get "player_ref" "$stat")
}

set_player_stat() {
  local stat=$1
  local value=$2
  obj_set "player_ref" "$stat" "$value"
}

create_basic_inventory() {
  unset potion1_ref
  declare -gA potion1_ref=()
  unset potion2_ref
  declare -gA potion2_ref=()
  unset potion3_ref
  declare -gA potion3_ref=()
  unset potion4_ref
  declare -gA potion4_ref=()
  unset ration_ref
  declare -gA ration_ref=()
  create_blank_object "potion1_ref"
  create_blank_object "potion2_ref"
  create_blank_object "potion3_ref"
  create_blank_object "potion4_ref"
  create_blank_object "ration_ref"
  register_item "potion1_ref"
  register_item "potion2_ref"
  register_item "potion3_ref"
  register_item "potion4_ref"
  register_item "ration_ref"
  obj_set "potion1_ref" "name" "Minor Healing Potion"
  obj_set "potion2_ref" "name" "Minor Healing Potion"
  obj_set "potion3_ref" "name" "Minor Healing Potion"
  obj_set "potion4_ref" "name" "Minor Healing Potion"
  obj_set "ration_ref" "name" "Ration"
  obj_set "potion1_ref" "hp" 10
  obj_set "potion2_ref" "hp" 10
  obj_set "potion3_ref" "hp" 10
  obj_set "potion4_ref" "hp" 10
  obj_set "ration_ref" "hp" 3
  obj_set "ration_ref" "mana" 3
  obj_set "potion1_ref" "type" 2
  obj_set "potion2_ref" "type" 2
  obj_set "potion3_ref" "type" 2
  obj_set "potion4_ref" "type" 2
  obj_set "ration_ref" "type" 2
  obj_set "potion1_ref" "subtype" 6
  obj_set "potion2_ref" "subtype" 6
  obj_set "potion3_ref" "subtype" 6
  obj_set "potion4_ref" "subtype" 6
  obj_set "ration_ref" "subtype" 8
  obj_set "potion1_ref" "equiped" 1
  obj_set "potion2_ref" "equiped" 1
  obj_set "potion3_ref" "equiped" 1
  obj_set "potion4_ref" "equiped" 1
  obj_set "ration_ref" "in_inventory" 1
  create_item_icon "potion1_ref"
  create_item_icon "potion2_ref"
  create_item_icon "potion3_ref"
  create_item_icon "potion4_ref"
  create_item_icon "ration_ref"
  set_player_stat "potion1" "potion1_ref"
  set_player_stat "potion2" "potion2_ref"
  set_player_stat "potion3" "potion3_ref"
  set_player_stat "potion4" "potion4_ref"
  set_player_stat "inventory1" "ration_ref"
}

new_player() {
  create_blank_object "player_ref"
  echo -ne "\e[2J\e[?25l"
  trap 'echo -ne "\e[?25h"' EXIT
  local prompt="Enter your name:"
  local prompt_x=$((TERM_WIDTH / 2 - ${#prompt} / 2))
  local prompt_y=$((TERM_HEIGHT / 2))
  echo -ne "\e[${prompt_y};${prompt_x}H${prompt}\e[0m"
  echo -ne "\e[$((prompt_y + 1));$((TERM_WIDTH / 2 - 10))H> "
  echo -ne "\e[?25h"
  read -r player_name
  echo -ne "\e[?25l"
  [[ -z "$player_name" ]] && player_name="Hero"
  set_player_stat "name" "$player_name"
  set_player_stat "map" "overworld"
  set_player_stat "map_type" 4
  set_player_stat "level" 1
  set_player_stat "hp" 25
  set_player_stat "mana" 10
  set_player_stat "hp_max" 25
  set_player_stat "mana_max" 10
  set_player_stat "strength" 1
  set_player_stat "vitality" 1
  set_player_stat "energy" 1
  set_player_stat "dexterity" 1
  set_player_stat "defense" 1
  set_player_stat "min_damage" 1
  set_player_stat "max_damage" 4
  set_player_stat "block_rate" 1
  set_player_stat "next_level_exp" 400
  set_player_stat "experience" 0
  set_player_stat "icon" "@"
  set_player_stat "fg_color" "36"
  create_basic_inventory
}

save_player() {
  obj_store "player_ref" "save" "player_ref"
}

load_player() {
  declare -g -A player_ref
  obj_load player_ref "save" "player_ref"
}

level_up_apply_stats() {
  local vitality strength energy dexterity
  vitality=$(get_player_stat "vitality")
  strength=$(get_player_stat "strength")
  energy=$(get_player_stat "energy")
  dexterity=$(get_player_stat "dexterity")
  local hp_max mana_max min_damage max_damage defense block_rate
  hp_max=$(get_player_stat "hp_max")
  mana_max=$(get_player_stat "mana_max")
  min_damage=$(get_player_stat "min_damage")
  max_damage=$(get_player_stat "max_damage")
  defense=$(get_player_stat "defense")
  block_rate=$(get_player_stat "block_rate")
  hp_max=$((hp_max + 5 + vitality))
  mana_max=$((mana_max + energy + 3))
  min_damage=$((min_damage + strength))
  max_damage=$((max_damage + strength))
  defense=$((defense + dexterity))
  block_rate=$((block_rate + dexterity / 4))
  set_player_stat "hp_max" "$hp_max"
  set_player_stat "mana_max" "$mana_max"
  set_player_stat "min_damage" "$min_damage"
  set_player_stat "max_damage" "$max_damage"
  set_player_stat "defense" "$defense"
  set_player_stat "block_rate" "$block_rate"
  set_player_stat "hp" "$hp_max"
  set_player_stat "mana" "$mana_max"
  show_level_up
}

check_level_up() {
  local exp next_exp level new_level total_exp
  exp=$(get_player_stat "experience")
  next_exp=$(get_player_stat "next_level_exp")
  if ((exp >= next_exp)); then
    level=$(get_player_stat "level")
    new_level=$((level + 1))
    set_player_stat "prev_level_exp" "$next_exp"
    set_player_stat "level" "$new_level"
    total_exp=$(((new_level * (new_level + 1) / 2) * 400))
    set_player_stat "next_level_exp" "$total_exp"
    print_ui "" "You gained a level"
    level_up_apply_stats
  fi
}

save_inventory() {
  mkdir -p save/inventory/potion1
  mkdir -p save/inventory/potion2
  mkdir -p save/inventory/potion3
  mkdir -p save/inventory/potion4
  mkdir -p save/inventory/inventory1
  mkdir -p save/inventory/inventory2
  mkdir -p save/inventory/inventory3
  mkdir -p save/inventory/inventory4
  mkdir -p save/inventory/inventory5
  mkdir -p save/inventory/inventory6
  mkdir -p save/inventory/inventory7
  mkdir -p save/inventory/inventory8
  mkdir -p save/inventory/weapon
  mkdir -p save/inventory/shield
  mkdir -p save/inventory/helmet
  mkdir -p save/inventory/armor
  mkdir -p save/inventory/amulet
  mkdir -p save/inventory/ring
  local epotion1_ref epotion2_ref epotion3_ref eepotion4_ref
  epotion1_ref=$(get_player_stat "potion1")
  epotion2_ref=$(get_player_stat "potion2")
  epotion3_ref=$(get_player_stat "potion3")
  epotion4_ref=$(get_player_stat "potion4")
  local inventory1_ref inventory2_ref inventory3_ref inventory4_ref
  local inventory5_ref inventory6_ref inventory7_ref inventory8_ref
  inventory1_ref=$(get_player_stat "inventory1")
  inventory2_ref=$(get_player_stat "inventory2")
  inventory3_ref=$(get_player_stat "inventory3")
  inventory4_ref=$(get_player_stat "inventory4")
  inventory5_ref=$(get_player_stat "inventory5")
  inventory6_ref=$(get_player_stat "inventory6")
  inventory7_ref=$(get_player_stat "inventory7")
  inventory8_ref=$(get_player_stat "inventory8")
  local weapon shield helmet armor amulet ring
  weapon_ref=$(get_player_stat "weapon")
  shield_ref=$(get_player_stat "shield")
  helmet_ref=$(get_player_stat "helmet")
  armor_ref=$(get_player_stat "armor")
  amulet_ref=$(get_player_stat "amulet")
  ring_ref=$(get_player_stat "ring")
  obj_store "$epotion1_ref" "save/inventory/potion1" "$epotion1_ref"
  obj_store "$epotion2_ref" "save/inventory/potion2" "$epotion2_ref"
  obj_store "$epotion3_ref" "save/inventory/potion3" "$epotion3_ref"
  obj_store "$epotion4_ref" "save/inventory/potion4" "$epotion4_ref"
  obj_store "$inventory1_ref" "save/inventory/inventory1" "$inventory1_ref"
  obj_store "$inventory2_ref" "save/inventory/inventory2" "$inventory2_ref"
  obj_store "$inventory3_ref" "save/inventory/inventory3" "$inventory3_ref"
  obj_store "$inventory4_ref" "save/inventory/inventory4" "$inventory4_ref"
  obj_store "$inventory5_ref" "save/inventory/inventory5" "$inventory5_ref"
  obj_store "$inventory6_ref" "save/inventory/inventory6" "$inventory6_ref"
  obj_store "$inventory7_ref" "save/inventory/inventory7" "$inventory7_ref"
  obj_store "$inventory8_ref" "save/inventory/inventory8" "$inventory9_ref"
  obj_store "$weapon_ref" "save/inventory/weapon" "$weapon_ref"
  obj_store "$shield_ref" "save/inventory/shield" "$shield_ref"
  obj_store "$helmet_ref" "save/inventory/helmet" "$helmet_ref"
  obj_store "$armor_ref" "save/inventory/armor" "$armor_ref"
  obj_store "$amulet_ref" "save/inventory/amulet" "$amulet_ref"
  obj_store "$ring_ref" "save/inventory/ring" "$ring_ref"
}

load_inventory() {
  local slot
  local ref
  local file
  local slots=(
    potion1 potion2 potion3 potion4
    inventory1 inventory2 inventory3 inventory4
    inventory5 inventory6 inventory7 inventory8
    weapon shield helmet armor amulet ring
  )
  for slot in "${slots[@]}"; do
    local dir="save/inventory/$slot"
    if [[ ! -d "$dir" ]]; then
      continue
    fi
    file=$(ls -1 "$dir" 2>/dev/null | head -n 1)
    if [[ -z "$file" ]]; then
      continue
    fi
    ref="${file}"
    declare -gA "$ref"
    obj_load "$ref" "$dir" "$ref"
    rm "$dir/$ref"
    register_item "$ref"
    set_player_stat "$slot" "$ref"
  done
}
