round_min1() {
  local value=$1
  local rounded
  rounded=$(printf "%.0f" "$value")
  ((rounded < 1)) && rounded=1
  echo "$rounded"
}

obj_get() {
  local -n obj_ref=$1
  local key=$2
  echo "${obj_ref[$key]}"
}

obj_set() {
  local -n obj_ref=$1
  local key=$2
  local value=$3
  obj_ref["$key"]="$value"
}

obj_store() {
  local ref_param="$1"
  local dir="$2"
  local file="$3"
  if [[ -z "$dir" || -z "$file" ]]; then
    return 1
  fi
  local assoc_name=""
  if declare -p "$ref_param" &>/dev/null && declare -p "$ref_param" 2>/dev/null | grep -q 'declare \-A' 2>/dev/null; then
    assoc_name="$ref_param"
  else
    if [[ -n "${!ref_param}" ]] && declare -p "${!ref_param}" 2>/dev/null | grep -q 'declare \-A' 2>/dev/null; then
      assoc_name="${!ref_param}"
    else
      if declare -p "$ref_param" 2>/dev/null | grep -q 'declare \-A' 2>/dev/null; then
        assoc_name="$ref_param"
      fi
    fi
  fi
  if [[ -z "$assoc_name" ]]; then
    return 1
  fi
  local -n obj_ref="$assoc_name"
  mkdir -p "$dir"
  local keys=(
    x y type name hp mana strength vitality energy dexterity
    defense min_damage max_damage
    fire_resistence cold_resistence poison_resistence lightning_resistence
    block_rate
    fire_damage_min fire_damage_max
    cold_damage_min cold_damage_max
    poison_damage poison_damage_time
    lightning_damage_min lightning_damage_max
    poisoned poison_time poison_time_max
    subtype weapon shield helmet armor amulet ring
    inventory1 inventory2 inventory3 inventory4
    inventory5 inventory6 inventory7 inventory8 experience level
    potion1 potion2 potion3 potion4 perk icon hp_max mana_max
    next_level_exp fg_color bg_color equiped in_inventory map map_type
    target_x target_y target_map poison_amount prev_level_exp prev_map
    lastx lasty location value gold in_npc_inv safe_map safe_x safe_y
    safe_subtype safe_location safe_lastx safe_lasty
  )
  {
    for k in "${keys[@]}"; do
      printf '%s\n' "${obj_ref[$k]:-}"
    done
  } >"$dir/$file"
  return 0
}

obj_load() {
  local ref_param="$1"
  local dir="$2"
  local filename="$3"
  if [[ -z "$dir" || -z "$filename" ]]; then
    return 1
  fi
  local file="$dir/$filename"
  if [[ ! -f "$file" ]]; then
    return 1
  fi
  local assoc_name=""
  if declare -p "$ref_param" &>/dev/null && declare -p "$ref_param" 2>/dev/null | grep -q 'declare \-A' 2>/dev/null; then
    assoc_name="$ref_param"
  else
    if [[ -n "${!ref_param}" ]] && declare -p "${!ref_param}" 2>/dev/null | grep -q 'declare \-A' 2>/dev/null; then
      assoc_name="${!ref_param}"
    else
      if declare -p "$ref_param" 2>/dev/null | grep -q 'declare \-A' 2>/dev/null; then
        assoc_name="$ref_param"
      fi
    fi
  fi
  if [[ -z "$assoc_name" ]]; then
    return 1
  fi
  local -n obj_ref="$assoc_name"
  local keys=(
    x y type name hp mana strength vitality energy dexterity
    defense min_damage max_damage
    fire_resistence cold_resistence poison_resistence lightning_resistence
    block_rate
    fire_damage_min fire_damage_max
    cold_damage_min cold_damage_max
    poison_damage poison_damage_time
    lightning_damage_min lightning_damage_max
    poisoned poison_time poison_time_max
    subtype weapon shield helmet armor amulet ring
    inventory1 inventory2 inventory3 inventory4
    inventory5 inventory6 inventory7 inventory8 experience level
    potion1 potion2 potion3 potion4 perk icon hp_max mana_max
    next_level_exp fg_color bg_color equiped in_inventory map map_type
    target_x target_y target_map poison_amount prev_level_exp prev_map
    lastx lasty location value gold in_npc_inv safe_map safe_x safe_y
    safe_subtype safe_location safe_lastx safe_lasty
  )
  local i=0
  while IFS= read -r line && [[ $i -lt ${#keys[@]} ]]; do
    obj_ref[${keys[$i]}]="$line"
    ((i++))
  done <"$file"
  for (( ; i < ${#keys[@]}; i++)); do
    obj_ref[${keys[$i]}]=""
  done
  return 0
}

#types
player=0
npc=1
item=2
portal=3

#item subtypes
weapon=0
shield=1
helmet=2
armor=3
amulet=4
ring=5
healing_potion=6
mana_potion=7
food=8
money=9

#npc subtypes
monster=0
merchant=1
healer=2
dummy=3
innkeeper=4
quester=5
main_quester=6

#perk item types
normal=0
magic=1
rare=2
unique=3

#perk monster types
normal=0
tough=1
elite=2
boss=3

#portal subype
dungeon=0
ruins=1
village=2
town=3

#map_type
overworld=4

create_blank_object() {
  local name=$1
  declare -gA "$name"
  declare -n obj_ref=$name
  obj_ref[x]=0
  obj_ref[y]=0
  obj_ref[type]=0
  obj_ref[name]=""
  obj_ref[hp]=0
  obj_ref[mana]=0
  obj_ref[strength]=0
  obj_ref[vitality]=0
  obj_ref[energy]=0
  obj_ref[dexterity]=0
  obj_ref[defense]=0
  obj_ref[min_damage]=0
  obj_ref[max_damage]=0
  obj_ref[fire_resistence]=0
  obj_ref[cold_resistence]=0
  obj_ref[poison_resistence]=0
  obj_ref[lightning_resistence]=0
  obj_ref[block_rate]=0
  obj_ref[fire_damage_min]=0
  obj_ref[fire_damage_max]=0
  obj_ref[cold_damage_min]=0
  obj_ref[cold_damage_max]=0
  obj_ref[poison_damage]=0
  obj_ref[poison_damage_time]=0
  obj_ref[lightning_damage_min]=0
  obj_ref[lightning_damage_max]=0
  obj_ref[poisoned]=0
  obj_ref[poison_time]=0
  obj_ref[poison_time_max]=0
  obj_ref[subtype]=0
  obj_ref[weapon]=""
  obj_ref[shield]=""
  obj_ref[helmet]=""
  obj_ref[armor]=""
  obj_ref[amulet]=""
  obj_ref[ring]=""
  obj_ref[inventory1]=""
  obj_ref[inventory2]=""
  obj_ref[inventory3]=""
  obj_ref[inventory4]=""
  obj_ref[inventory5]=""
  obj_ref[inventory6]=""
  obj_ref[inventory7]=""
  obj_ref[inventory8]=""
  obj_ref[experience]=0
  obj_ref["level"]=0
  obj_ref[potion1]=""
  obj_ref[potion2]=""
  obj_ref[potion3]=""
  obj_ref[potion4]=""
  obj_ref[perk]=0
  obj_ref[icon]=""
  obj_ref[hp_max]=0
  obj_ref[mana_max]=0
  obj_ref[next_level_exp]=0
  obj_ref[bg_color]=""
  obj_ref[fg_color]=""
  obj_ref[equiped]=0
  obj_ref[in_inventory]=0
  obj_ref[map]=""
  obj_ref[map_type]=0
  obj_ref[target_x]=0
  obj_ref[target_y]=0
  obj_ref[target_map]=""
  obj_ref[poison_amount]=0
  obj_ref[prev_level_exp]=0
  obj_ref[prev_map]=""
  obj_ref[lastx]=0
  obj_ref[lasty]=0
  obj_ref[location]=""
  obj_ref[value]=0
  obj_ref[gold]=0
  obj_ref[in_npc_inv]=0
  obj_ref[safe_map]=""
  obj_ref[safe_x]=0
  obj_ref[safe_y]=0
  obj_ref[safe_subtype]=0
  obj_ref[safe_location]=""
  obj_ref[safe_lastx]=0
  obj_ref[safe_lasty]=0
}

destroy_object() {
  local -n obj_ref=$1
  declare -p "$obj_ref" &>/dev/null && unset "$obj_ref"
}
