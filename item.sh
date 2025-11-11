[[ -n "${_ITEM_SH_INCLUDED:-}" ]] && return
_ITEM_SH_INCLUDED=1

source object.sh
source ui.sh
source player.sh
source npc.sh
source map.sh

if [[ -z "${ITEM_REGISTRY_LOADED:-}" ]]; then
  declare -ag ITEM_REGISTRY=()
  ITEM_REGISTRY_LOADED=1
fi

register_item() {
  local item_ref=$1
  local item
  for item in "${ITEM_REGISTRY[@]}"; do
    if [[ "$item" == "$item_ref" ]]; then
      return 1
    fi
  done
  ITEM_REGISTRY+=("$item_ref")
}

unregister_item() {
  local item_ref=$1
  local new_registry=()
  local item
  for item in "${ITEM_REGISTRY[@]}"; do
    if [[ "$item" != "$item_ref" ]]; then
      new_registry+=("$item")
    fi
  done
  ITEM_REGISTRY=("${new_registry[@]}")
}

log_item_registry() {
    local log_file="debug.log"
    echo "===== ITEM_REGISTRY =====" >> "$log_file"
    local item
    for item in "${ITEM_REGISTRY[@]}"; do
        echo "$item" >> "$log_file"
    done
    echo "=========================" >> "$log_file"
}


get_item_obj_ref() {
  local prefix=$1
  local used_ids=()
  local item
  for item in "${ITEM_REGISTRY[@]}"; do
    if [[ "$item" =~ ^${prefix}item([0-9]+)$ ]]; then
      used_ids+=("${BASH_REMATCH[1]}")
    fi
  done
  local id=1
  while :; do
    local found=0
    for used in "${used_ids[@]}"; do
      if ((10#$used == id)); then
        found=1
        break
      fi
    done
    [[ $found -eq 0 ]] && break
    ((id++))
  done
  local item_ref
  printf -v item_ref "%sitem%03d" "$prefix" "$id"
  unset "$item_ref"
  declare -gA "$item_ref=()"
  assigned_item_ref="$item_ref"
}

set_item_value() {
    local item_ref="$1"
    local subtype=$(obj_get "$item_ref" "subtype")
    [[ "$subtype" == "9" ]] && return
    local value=0
    local defense
    local min_damage max_damage
    local fire_resistence cold_resistence poison_resistence lightning_resistence
    local block_rate
    local fire_damage_min fire_damage_max
    local cold_damage_min cold_damage_max
    local poison_damage poison_damage_time
    local lightning_damage_min lightning_damage_max
    local hp mana
    defense=$(obj_get "$item_ref" "defense")
    min_damage=$(obj_get "$item_ref" "min_damage")
    max_damage=$(obj_get "$item_ref" "max_damage")
    fire_resistence=$(obj_get "$item_ref" "fire_resistence")
    cold_resistence=$(obj_get "$item_ref" "cold_resistence")
    poison_resistence=$(obj_get "$item_ref" "poison_resistence")
    lightning_resistence=$(obj_get "$item_ref" "lightning_resistence")
    block_rate=$(obj_get "$item_ref" "block_rate")
    fire_damage_min=$(obj_get "$item_ref" "fire_damage_min")
    fire_damage_max=$(obj_get "$item_ref" "fire_damage_max")
    cold_damage_min=$(obj_get "$item_ref" "cold_damage_min")
    cold_damage_max=$(obj_get "$item_ref" "cold_damage_max")
    poison_damage=$(obj_get "$item_ref" "poison_damage")
    poison_damage_time=$(obj_get "$item_ref" "poison_damage_time")
    lightning_damage_min=$(obj_get "$item_ref" "lightning_damage_min")
    lightning_damage_max=$(obj_get "$item_ref" "lightning_damage_max")
    hp=$(obj_get "$item_ref" "hp")
    mana=$(obj_get "$item_ref" "mana")
    (( value += defense * 5 ))
    (( value += block_rate * 5 ))
    (( value += (min_damage + max_damage) * 2 ))
    (( value += fire_resistence * 5 ))
    (( value += cold_resistence * 5 ))
    (( value += poison_resistence * 5 ))
    (( value += lightning_resistence * 5 ))
    (( value += poison_damage * 5 ))
    (( value += (fire_damage_min + fire_damage_max) * 5 ))
    (( value += (cold_damage_min + cold_damage_max) * 5 ))
    (( value += (lightning_damage_min + lightning_damage_max) * 5 ))
    (( value += hp ))
    (( value += mana ))
    obj_set "$item_ref" "value" "$value"
}


gen_item_name() {
  local perk=$1
  local subtype=$2
  local base_name
  case $subtype in
    0) base_name=("Sword" "Axe" "Dagger" "Mace" "Spear" "Staff" "Club" "Hammer") ;;
    1) base_name=("Shield" "Buckler" "Tower Shield" "Ward") ;;
    2) base_name=("Helm" "Cap" "Crown" "Mask") ;;
    3) base_name=("Armor" "Plate" "Robe" "Mail") ;;
    4) base_name=("Amulet" "Pendant" "Charm") ;;
    5) base_name=("Ring" "Band" "Loop") ;;
    6) base_name=("Healing Potion" "Red Potion" "Health Flask") ;;
    7) base_name=("Mana Potion" "Blue Potion" "Energy Flask") ;;
    8) base_name=("Bread" "Meat" "Cheese" "Ration") ;;
    9) base_name=("Gold") ;;
    *) base_name=("Item") ;;
  esac
  local prefix=()
  local suffix=()
  case $perk in
    0) # Normal
      prefix=("" "")
      suffix=("" "")
      ;;
    1) # Magic
      prefix=("Fiery" "Frozen" "Blessed" "Cursed" "Shimmering" "Strong" "Dark")
      suffix=("of Power" "of Swiftness" "of Might" "of Frost" "of Flame" "of Focus")
      ;;
    2) # Rare
      prefix=("Ancient" "Glorious" "Mystic" "Vicious" "Shadowed" "Sacred" "Infernal")
      suffix=("of the Lion" "of the Phoenix" "of the Titan" "of the Wolf" "of the Sage" "of Doom")
      ;;
    3) # Unique
      prefix=("The Eternal" "The Forgotten" "The Holy" "The Infernal" "The Last" "The Primeval")
      suffix=("of Destiny" "of Shadows" "of Immortality" "of Destruction" "of the Gods")
      ;;
    *)
      prefix=("" "")
      suffix=("" "")
      ;;
  esac
  local pfx="${prefix[$((RANDOM % ${#prefix[@]}))]}"
  local base="${base_name[$((RANDOM % ${#base_name[@]}))]}"
  local sfx="${suffix[$((RANDOM % ${#suffix[@]}))]}"
  local full_name
  case $perk in
    0) full_name="$base" ;;
    1 | 2) full_name="$pfx $base $sfx" ;;
    3) full_name="$pfx $base $sfx" ;;
  esac
  echo "$full_name" | sed 's/  */ /g'
}

create_random_normal_item() {
  local level=$1
  local item_ref=$2
  local rnd
  rnd=$((RANDOM % 100))
  local subtype
  if ((rnd < 30)); then
    subtype=8 # jídlo
  elif ((rnd < 35)); then
    subtype=6 # healing potion
  elif ((rnd < 40)); then
    subtype=7 # mana potion
  else
    rnd=$((RANDOM % 5))
    case $rnd in
      0) subtype=0 ;; # weapon
      1) subtype=1 ;; # shield
      2) subtype=2 ;; # helmet
      3) subtype=3 ;; # armor
      4) subtype=9 ;; # gold
    esac
  fi
  obj_set "$item_ref" "subtype" "$subtype"
  case $subtype in
    0) # weapon
      obj_set "$item_ref" "min_damage" $((RANDOM % (level / 2 + 1) + level / 2 + 1))
      obj_set "$item_ref" "max_damage" $((RANDOM % (level + 1) + level))
      ;;
    1) # shield
      obj_set "$item_ref" "defense" $((RANDOM % (level / 2 + 1) + level / 2 + 1))
      obj_set "$item_ref" "block_rate" $((level))
      # maximálně 30
      local br=$(obj_get "$item_ref" "block_rate")
      if ((br > 30)); then obj_set "$item_ref" "block_rate" 30; fi
      ;;
    2) # helmet
      obj_set "$item_ref" "defense" $((RANDOM % (level / 2 + 1) + level / 2 + 1))
      ;;
    3) # armor
      obj_set "$item_ref" "defense" $((RANDOM % (level + 1) + level))
      ;;
    6) # healing potion
      obj_set "$item_ref" "hp" $((RANDOM % (2 * level) + 3))
      ;;
    7) # mana potion
      obj_set "$item_ref" "mana" $((RANDOM % (2 * level) + 3))
      ;;
    8) # food
      obj_set "$item_ref" "hp" $((RANDOM % (level / 2 + 1) + level / 2 + 1))
      obj_set "$item_ref" "mana" $((RANDOM % (level / 2 + 1) + level / 2 + 1))
      ;;
    9) # gold
      obj_set "$item_ref" "value" $((RANDOM % (level + 1) + level))
     esac
  local name
  name=$(gen_item_name 0 "$subtype")
  obj_set "$item_ref" "name" "$name"
  set_item_value "$item_ref"
}

create_random_normal_item_no_gold() {
  local level=$1
  local item_ref=$2
  local rnd
  rnd=$((RANDOM % 100))
  local subtype
  if ((rnd < 30)); then
    subtype=8 # jídlo
  elif ((rnd < 35)); then
    subtype=6 # healing potion
  elif ((rnd < 40)); then
    subtype=7 # mana potion
  else
    rnd=$((RANDOM % 4))
    case $rnd in
      0) subtype=0 ;; # weapon
      1) subtype=1 ;; # shield
      2) subtype=2 ;; # helmet
      3) subtype=3 ;; # armor
    esac
  fi
  obj_set "$item_ref" "subtype" "$subtype"
  case $subtype in
    0) # weapon
      obj_set "$item_ref" "min_damage" $((RANDOM % (level / 2 + 1) + level / 2 + 1))
      obj_set "$item_ref" "max_damage" $((RANDOM % (level + 1) + level))
      ;;
    1) # shield
      obj_set "$item_ref" "defense" $((RANDOM % (level / 2 + 1) + level / 2 + 1))
      obj_set "$item_ref" "block_rate" $((level))
      # maximálně 30
      local br=$(obj_get "$item_ref" "block_rate")
      if ((br > 30)); then obj_set "$item_ref" "block_rate" 30; fi
      ;;
    2) # helmet
      obj_set "$item_ref" "defense" $((RANDOM % (level / 2 + 1) + level / 2 + 1))
      ;;
    3) # armor
      obj_set "$item_ref" "defense" $((RANDOM % (level + 1) + level))
      ;;
    6) # healing potion
      obj_set "$item_ref" "hp" $((RANDOM % (2 * level) + 3))
      ;;
    7) # mana potion
      obj_set "$item_ref" "mana" $((RANDOM % (2 * level) + 3))
      ;;
    8) # food
      obj_set "$item_ref" "hp" $((RANDOM % (level / 2 + 1) + level / 2 + 1))
      obj_set "$item_ref" "mana" $((RANDOM % (level / 2 + 1) + level / 2 + 1))
      ;;
  esac
  local name
  name=$(gen_item_name 0 "$subtype")
  obj_set "$item_ref" "name" "$name"
  set_item_value "$item_ref"
}

create_random_healing_potion() {
  local level=$1
  local item_ref=$2
  obj_set "$item_ref" "subtype" 6
  obj_set "$item_ref" "hp" $((RANDOM % (2 * level) + 3))
  local name
  name=$(gen_item_name 0 6)
  obj_set "$item_ref" "name" "$name"
  set_item_value "$item_ref"
}

create_random_mana_potion() {
  local level=$1
  local item_ref=$2
  obj_set "$item_ref" "subtype" 7
  obj_set "$item_ref" "mana" $((RANDOM % (2 * level) + 3))
  local name
  name=$(gen_item_name 0 7)
  obj_set "$item_ref" "name" "$name"
  set_item_value "$item_ref"
}

create_random_food() {
  local level=$1
  local item_ref=$2
  obj_set "$item_ref" "subtype" 8
  obj_set "$item_ref" "hp" $((RANDOM % (level / 2 + 1) + level / 2 + 1))
  obj_set "$item_ref" "mana" $((RANDOM % (level / 2 + 1) + level / 2 + 1))
  local name
  name=$(gen_item_name 0 8)
  obj_set "$item_ref" "name" "$name"
  set_item_value "$item_ref"
}

create_random_magic_item() {
  local level=$1
  local item_ref=$2
  local rnd=$((RANDOM % 100))
  local subtype
  if ((rnd < 5)); then
    subtype=4 # amulet
  elif ((rnd < 10)); then
    subtype=5 # ring
  else
    rnd=$((RANDOM % 4))
    case $rnd in
      0) subtype=0 ;; # weapon
      1) subtype=1 ;; # shield
      2) subtype=2 ;; # helmet
      3) subtype=3 ;; # armor
    esac
  fi
  obj_set "$item_ref" "subtype" "$subtype"
  case $subtype in
    0) # weapon
      obj_set "$item_ref" "min_damage" $((RANDOM % (level / 2 + 1) + level / 2 + 1))
      obj_set "$item_ref" "max_damage" $((RANDOM % (level + 1) + level))
      ;;
    1) # shield
      obj_set "$item_ref" "defense" $((RANDOM % (level / 2 + 1) + level / 2 + 1))
      obj_set "$item_ref" "block_rate" $((level))
      local br=$(obj_get "$item_ref" "block_rate")
      ((br > 30)) && obj_set "$item_ref" "block_rate" 30
      ;;
    2) # helmet
      obj_set "$item_ref" "defense" $((RANDOM % (level / 2 + 1) + level / 2 + 1))
      ;;
    3) # armor
      obj_set "$item_ref" "defense" $((RANDOM % (level + 1) + level))
      ;;
  esac
  local props=("defense" "min_damage" "max_damage"
    "fire_resistence" "cold_resistence" "poison_resistence" "lightning_resistence"
    "fire_damage_min" "fire_damage_max"
    "cold_damage_min" "cold_damage_max"
    "poison_damage" "poison_damage_time"
    "lightning_damage_min" "lightning_damage_max")
  local num_props=2
  local available_props=("${props[@]}")
  local selected_props=()
  while ((num_props > 0 && ${#available_props[@]} > 0)); do
    local idx=$((RANDOM % ${#available_props[@]}))
    local prop="${available_props[$idx]}"
    unset 'available_props[idx]'
    available_props=("${available_props[@]}")
    case $prop in
      defense | min_damage | max_damage)
        if ((subtype == 4 || subtype == 5)); then
          obj_set "$item_ref" "$prop" $((RANDOM % (level / 2 + 1) + level / 2 + 1))
          ((num_props--))
        fi
        ;;
      fire_damage_min | cold_damage_min | lightning_damage_min)
        if ((subtype == 0 || subtype == 4 || subtype == 5)); then
          obj_set "$item_ref" "$prop" $((RANDOM % (level / 2 + 1) + level / 2 + 1))
          ((num_props--))
        fi
        ;;
      fire_damage_max | cold_damage_max | lightning_damage_max)
        if ((subtype == 0 || subtype == 4 || subtype == 5)); then
          obj_set "$item_ref" "$prop" $((RANDOM % (level + 1) + level))
          ((num_props--))
        fi
        ;;
      poison_damage)
        if ((subtype == 0 || subtype == 4 || subtype == 5)); then
          obj_set "$item_ref" "$prop" $((RANDOM % (level + 1) + level))
          ((num_props--))
        fi
        ;;
      poison_damage_time)
        if ((subtype == 0 || subtype == 4 || subtype == 5)); then
          obj_set "$item_ref" "$prop" $((RANDOM % (3 * level) + level))
          ((num_props--))
        fi
        ;;
      fire_resistence | cold_resistence | poison_resistence | lightning_resistence)
        if ((subtype == 1 || subtype == 2 || subtype == 3 || subtype == 4 || subtype == 5)); then
          obj_set "$item_ref" "$prop" $((RANDOM % (level / 2 + 1) + level / 2 + 1))
          ((num_props--))
        fi
        ;;
    esac
  done
  local name
  name=$(gen_item_name 1 "$subtype")
  obj_set "$item_ref" "name" "$name"
  set_item_value "$item_ref"
}

create_random_rare_item() {
  local level=$1
  local item_ref=$2
  local rnd=$((RANDOM % 100))
  local subtype
  if ((rnd < 5)); then
    subtype=4 # amulet
  elif ((rnd < 10)); then
    subtype=5 # ring
  else
    rnd=$((RANDOM % 4))
    case $rnd in
      0) subtype=0 ;; # weapon
      1) subtype=1 ;; # shield
      2) subtype=2 ;; # helmet
      3) subtype=3 ;; # armor
    esac
  fi
  obj_set "$item_ref" "subtype" "$subtype"
  case $subtype in
    0) # weapon
      obj_set "$item_ref" "min_damage" $((RANDOM % (level / 2 + 1) + level / 2 + 1))
      obj_set "$item_ref" "max_damage" $((RANDOM % (level + 1) + level))
      ;;
    1) # shield
      obj_set "$item_ref" "defense" $((RANDOM % (level / 2 + 1) + level / 2 + 1))
      obj_set "$item_ref" "block_rate" $((level))
      local br=$(obj_get "$item_ref" "block_rate")
      ((br > 30)) && obj_set "$item_ref" "block_rate" 30
      ;;
    2) # helmet
      obj_set "$item_ref" "defense" $((RANDOM % (level / 2 + 1) + level / 2 + 1))
      ;;
    3) # armor
      obj_set "$item_ref" "defense" $((RANDOM % (level + 1) + level))
      ;;
  esac
  local props=("defense" "min_damage" "max_damage"
    "fire_resistence" "cold_resistence" "poison_resistence" "lightning_resistence"
    "fire_damage_min" "fire_damage_max"
    "cold_damage_min" "cold_damage_max"
    "poison_damage" "poison_damage_time"
    "lightning_damage_min" "lightning_damage_max")
  local num_props=4
  local available_props=("${props[@]}")
  local selected_props=()
  while ((num_props > 0 && ${#available_props[@]} > 0)); do
    local idx=$((RANDOM % ${#available_props[@]}))
    local prop="${available_props[$idx]}"
    unset 'available_props[idx]'
    available_props=("${available_props[@]}")
    case $prop in
      defense | min_damage | max_damage)
        if ((subtype == 4 || subtype == 5)); then
          obj_set "$item_ref" "$prop" $((RANDOM % (level / 2 + 1) + level / 2 + 1))
          ((num_props--))
        fi
        ;;
      fire_damage_min | cold_damage_min | lightning_damage_min)
        if ((subtype == 0 || subtype == 4 || subtype == 5)); then
          obj_set "$item_ref" "$prop" $((RANDOM % (level / 2 + 1) + level / 2 + 1))
          ((num_props--))
        fi
        ;;
      fire_damage_max | cold_damage_max | lightning_damage_max)
        if ((subtype == 0 || subtype == 4 || subtype == 5)); then
          obj_set "$item_ref" "$prop" $((RANDOM % (level + 1) + level))
          ((num_props--))
        fi
        ;;
      poison_damage)
        if ((subtype == 0 || subtype == 4 || subtype == 5)); then
          obj_set "$item_ref" "$prop" $((RANDOM % (level + 1) + level))
          ((num_props--))
        fi
        ;;
      poison_damage_time)
        if ((subtype == 0 || subtype == 4 || subtype == 5)); then
          obj_set "$item_ref" "$prop" $((RANDOM % (3 * level) + level))
          ((num_props--))
        fi
        ;;
      fire_resistence | cold_resistence | poison_resistence | lightning_resistence)
        if ((subtype == 1 || subtype == 2 || subtype == 3 || subtype == 4 || subtype == 5)); then
          obj_set "$item_ref" "$prop" $((RANDOM % (level / 2 + 1) + level / 2 + 1))
          ((num_props--))
        fi
        ;;
    esac
  done
  local name
  name=$(gen_item_name 2 "$subtype")
  obj_set "$item_ref" "name" "$name"
  set_item_value "$item_ref"
}

create_random_unique_item() {
  local level=$1
  local item_ref=$2
  local rnd=$((RANDOM % 100))
  local subtype
  if ((rnd < 5)); then
    subtype=4 # amulet
  elif ((rnd < 10)); then
    subtype=5 # ring
  else
    rnd=$((RANDOM % 4))
    case $rnd in
      0) subtype=0 ;; # weapon
      1) subtype=1 ;; # shield
      2) subtype=2 ;; # helmet
      3) subtype=3 ;; # armor
    esac
  fi
  obj_set "$item_ref" "subtype" "$subtype"
  case $subtype in
    0) # weapon
      obj_set "$item_ref" "min_damage" $(((RANDOM % (level / 2 + 1) + level / 2) * 3 / 2 + 1))
      obj_set "$item_ref" "max_damage" $(((RANDOM % (level + 1) + level) * 3 / 2 + 1))
      ;;
    1) # shield
      obj_set "$item_ref" "defense" $(((RANDOM % (level / 2 + 1) + level / 2) * 3 / 2 + 1))
      obj_set "$item_ref" "block_rate" $((level * 3 / 2 + 1))
      local br=$(obj_get "$item_ref" "block_rate")
      ((br > 30)) && obj_set "$item_ref" "block_rate" 30
      ;;
    2) # helmet
      obj_set "$item_ref" "defense" $(((RANDOM % (level / 2 + 1) + level / 2) * 3 / 2 + 1))
      ;;
    3) # armor
      obj_set "$item_ref" "defense" $(((RANDOM % (level + 1) + level) * 3 / 2))
      ;;
  esac
  local props=("defense" "min_damage" "max_damage"
    "fire_resistence" "cold_resistence" "poison_resistence" "lightning_resistence"
    "fire_damage_min" "fire_damage_max"
    "cold_damage_min" "cold_damage_max"
    "poison_damage" "poison_damage_time"
    "lightning_damage_min" "lightning_damage_max")
  local num_props=6
  local p7=$((15 + level / 2)) # lineární škálování pravděpodobnosti 7 vlastností
  ((p7 > 50)) && p7=50
  local p8=$((12 + level / 2)) # lineární škálování pravděpodobnosti 8 vlastností
  ((p8 > 40)) && p8=40
  local roll=$((RANDOM % 100))
  if ((roll < p8)); then
    num_props=8
  elif ((roll < p8 + p7)); then
    num_props=7
  fi
  local available_props=("${props[@]}")
  local selected_props=()
  while ((num_props > 0 && ${#available_props[@]} > 0)); do
    local idx=$((RANDOM % ${#available_props[@]}))
    local prop="${available_props[$idx]}"
    unset 'available_props[idx]'
    available_props=("${available_props[@]}")
    case $prop in
      defense | min_damage | max_damage)
        if ((subtype == 4 || subtype == 5)); then
          obj_set "$item_ref" "$prop" $(((RANDOM % (level / 2 + 1) + level / 2) * 3 / 2 + 1))
          ((num_props--))
        fi
        ;;
      fire_damage_min | cold_damage_min | lightning_damage_min)
        if ((subtype == 0 || subtype == 4 || subtype == 5)); then
          obj_set "$item_ref" "$prop" $(((RANDOM % (level / 2 + 1) + level / 2) * 3 / 2 + 1))
          ((num_props--))
        fi
        ;;
      fire_damage_max | cold_damage_max | lightning_damage_max)
        if ((subtype == 0 || subtype == 4 || subtype == 5)); then
          obj_set "$item_ref" "$prop" $(((RANDOM % (level + 1) + level) * 3 / 2 + 1))
          ((num_props--))
        fi
        ;;
      poison_damage)
        if ((subtype == 0 || subtype == 4 || subtype == 5)); then
          obj_set "$item_ref" "$prop" $(((RANDOM % (level + 1) + level) * 3 / 2))
          ((num_props--))
        fi
        ;;
      poison_damage_time)
        if ((subtype == 0 || subtype == 4 || subtype == 5)); then
          obj_set "$item_ref" "$prop" $(((RANDOM % (3 * level) + level) * 3 / 2))
          ((num_props--))
        fi
        ;;
      fire_resistence | cold_resistence | poison_resistence | lightning_resistence)
        if ((subtype == 1 || subtype == 2 || subtype == 3 || subtype == 4 || subtype == 5)); then
          obj_set "$item_ref" "$prop" $(((RANDOM % (level / 2 + 1) + level / 2) * 3 / 2 + 1))
          ((num_props--))
        fi
        ;;
    esac
  done
  local name
  name=$(gen_item_name 3 "$subtype")
  obj_set "$item_ref" "name" "$name"
  set_item_value "$item_ref"
}

create_item_icon() {
  local item_ref=$1
  local subtype
  local perk
  subtype=$(obj_get "$item_ref" "subtype")
  perk=$(obj_get "$item_ref" "perk")
  local icon_char
  case $subtype in
    0) icon_char="W" ;; # weapon
    1) icon_char="S" ;; # shield
    2) icon_char="H" ;; # helmet
    3) icon_char="A" ;; # armor
    4) icon_char="&" ;; # amulet
    5) icon_char="R" ;; # ring
    6) icon_char="P" ;; # healing potion
    7) icon_char="P" ;; # mana potion
    8) icon_char="F" ;; # food
    9) icon_char="G" ;; # gold
    *) icon_char="?" ;; # fallback
  esac
  local fg_color="39" # výchozí
  if [[ $subtype -eq 6 ]]; then
    fg_color="31" # červené pro HP lektvar
  elif [[ $subtype -eq 7 ]]; then
    fg_color="34" # modré pro Mana lektvar
  elif [[ $subtype -eq 8 ]]; then
    fg_color="31" # červené pro jídlo
  elif [[ $subtype -eq 9 ]]; then
    fg_color="33" # zlute pro penize
  fi
  local bg_color="40" # default černé pozadí
  case $perk in
    0) bg_color="40" ;; # normal - černé
    1) bg_color="44" ;; # magic - modré
    2) bg_color="43" ;; # rare - žluté
    3) bg_color="41" ;; # unique - červené
  esac
  local icon="$icon_char"
  obj_set "$item_ref" "icon" "$icon"
  obj_set "$item_ref" "fg_color" "$fg_color"
  obj_set "$item_ref" "bg_color" "$bg_color"
}

create_random_item() {
  local level=$1
  local item_ref
  local map=$(get_player_stat "map")
  get_item_obj_ref "$map"
  item_ref="$assigned_item_ref"
  create_blank_object "$item_ref"
  obj_set "$item_ref" "type" 2
  register_item "$item_ref"
  local base_common=10
  local base_unique=2000
  local step=$(((base_unique - base_common) / 3))
  local base_magic=$((base_common + step)) # ~673
  local base_rare=$((base_magic + step))   # ~1336
  local p_common=$(awk -v x=$base_common -v l=$level 'BEGIN{p=(l/x); if(p>0.5)p=0.5; print p}')
  local p_magic=$(awk -v x=$base_magic -v l=$level 'BEGIN{p=(l/x); if(p>0.5)p=0.5; print p}')
  local p_rare=$(awk -v x=$base_rare -v l=$level 'BEGIN{p=(l/x); if(p>0.5)p=0.5; print p}')
  local p_unique=$(awk -v x=$base_unique -v l=$level 'BEGIN{p=(l/x); if(p>0.5)p=0.5; print p}')
  local rand=$(awk -v r=$RANDOM 'BEGIN{srand(); print r/32767}')
  if (($(awk -v r=$rand -v p=$p_unique 'BEGIN{print (r<p)}'))); then
    create_random_unique_item "$level" "$item_ref"
    obj_set "$item_ref" "perk" 3
  elif (($(awk -v r=$rand -v p1=$p_unique -v p2=$p_rare 'BEGIN{print (r<(p1+p2))}'))); then
    create_random_rare_item "$level" "$item_ref"
    obj_set "$item_ref" "perk" 2
  elif (($(awk -v r=$rand -v p1=$p_unique -v p2=$p_rare -v p3=$p_magic 'BEGIN{print (r<(p1+p2+p3))}'))); then
    create_random_magic_item "$level" "$item_ref"
    obj_set "$item_ref" "perk" 1
  else
    create_random_normal_item "$level" "$item_ref"
    obj_set "$item_ref" "perk" 0
  fi
  create_item_icon "$item_ref"
  created_item_ref="$item_ref"
}

create_random_magic_item_no_reg() {
  local level=$2
  local item_ref=$1
  create_blank_object "$item_ref"
  obj_set "$item_ref" "type" 2
  create_random_magic_item "$level" "$item_ref"
  obj_set "$item_ref" "perk" 1
  create_item_icon "$item_ref"
}

iterate_over_items_par() {
  local func_name=$1
  shift
  local item_ref
   for item_ref in "${ITEM_REGISTRY[@]}"; do
    "$func_name" "$item_ref" "$@" &
  done
  wait
}

iterate_over_items() {
  local func_name=$1
  shift
  local item_ref
  for item_ref in "${ITEM_REGISTRY[@]}"; do
    "$func_name" "$item_ref" "$@"
  done
}

draw_item() {
    local item_ref=$1
    local px=$2
    local py=$3
    declare -n IT="$item_ref"
    [[ "${IT[equiped]}" == "1" || "${IT[in_inventory]}" == "1" ]] && return 0
    local x=${IT[x]}
    local y=${IT[y]}
    if ! in_viewport "$x" "$y"; then
        return 0
    fi
    local vx=$(( x - px + VIEWPORT_WIDTH/2 ))
    local vy=$(( y - py + VIEWPORT_HEIGHT/2 ))
    printf "%d;%d;%s;%s;%s\n" "$vx" "$vy" "${IT[icon]}" "${IT[bg_color]}" "${IT[fg_color]}"
}

draw_items() {
  local px=$PLAYER_X
  local py=$PLAYER_Y
  local line vx vy icon bg fg
  while IFS=';' read -r vx vy icon bg fg; do
    FRAME_BUFFER["$vx,$vy"]="\e[${bg};${fg}m${icon}\e[0m"
  done < <(iterate_over_items_par "draw_item" "$px" "$py")
}

item_on_xy_helper() {
  local item_ref=$1
  local x=$2
  local y=$3
  local itemx itemy in_inventory equiped
  itemx=$(obj_get "$item_ref" "x")
  itemy=$(obj_get "$item_ref" "y")
  in_inventory=$(obj_get "$item_ref" "in_inventory")
  equiped=$(obj_get "$item_ref" "equiped")
  if [[ "$in_inventory" -eq 0 && "$equiped" -eq 0 && "$x" == "$itemx" && "$y" == "$itemy" ]]; then
    echo "$item_ref"
  fi
}

item_on_xy() {
  local x=$1
  local y=$2
  local found
  found=$(iterate_over_items_par "item_on_xy_helper" "$x" "$y")
  if [[ -n "$found" ]]; then
    echo "$found"
  else
    echo ""
  fi
}

drop_loot() {
  local npc_ref=$1
  local level
  level=$(obj_get "$npc_ref" "level")
  local x y
  x=$(obj_get "$npc_ref" "x")
  y=$(obj_get "$npc_ref" "y")
  local existing_item
  existing_item=$(item_on_xy "$x" "$y")
  if [[ -n "$existing_item" ]]; then
    return
  fi
  local item_ref
  create_random_item "$level"
  item_ref="$created_item_ref"
  obj_set "$item_ref" "x" "$x"
  obj_set "$item_ref" "y" "$y"
}

destroy_item_abs() {
  local item_ref=$1
  unregister_item "$item_ref"
  destroy_object "$item_ref"
}

destroy_item() {
  local item_ref=$1
  local eq inv npc_inv
  eq=$(obj_get "$item_ref" "equiped")
  inv=$(obj_get "$item_ref" "in_inventory")
  npc_inv=$(obj_get "$item_ref" "in_npc_inv")
  if [[ "$npc_inv" -ne 1 && ( "$eq" -eq 1 || "$inv" -eq 1 ) ]]; then
    return 0
  fi
  unregister_item "$item_ref"
  destroy_object "$item_ref"
}

delete_all_items() {
  iterate_over_items "destroy_item"
}

destroy_hidden_item() {
    local item_ref=$1
    if [[ "$(get_player_stat "map_type")" -eq 0 ]]; then
     return
    fi
    declare -n IT="$item_ref"
    [[ "${IT[in_inventory]}" == "1" || "${IT[equiped]}" == "1" ]] && return 0
    local x="${IT[x]}"
    local y="${IT[y]}"
    [[ -z "$x" || -z "$y" ]] && return 0
    if ! in_viewport "$x" "$y"; then
        destroy_item "$item_ref"
    fi
}

destroy_hidden_items() {
  iterate_over_items destroy_hidden_item
}

save_item() {
    local item_ref="$1"
    local inv=$(obj_get "$item_ref" "in_inventory")
    local eq=$(obj_get "$item_ref" "equiped")

    local npc_inv
    npc_inv=$(obj_get "$item_ref" "in_npc_inv")
    if (( npc_inv == 0 && (eq == 1 || inv == 1) )); then
        return 0
    fi
    local map
    map=$(get_player_stat "map")
    mkdir -p "save/maps/$map.d/items"
    obj_store "$item_ref" "save/maps/${map}.d/items" "$item_ref"
}

save_items() {
  iterate_over_items_par save_item
}

load_items() {
  local map=$(get_player_stat "map")
  local dir="save/maps/$map.d/items"
  [[ ! -d "$dir" ]] && return
  shopt -s nullglob
  for file in "$dir"/*; do
    local base
    base=$(basename "$file")
    local item_ref="$base"
    declare -g -A "$item_ref"
    obj_load "$item_ref" "$dir" "$base"
    register_item "$item_ref"
  done
  shopt -u nullglob
  rm -rf "$dir"/*
}
