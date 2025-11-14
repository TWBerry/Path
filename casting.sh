[[ -n "${_CASTING_SH_INCLUDED:-}" ]] && return
_CASTING_SH_INCLUDED=1
source ui.sh
source npc.sh
source item.sh
source object.sh
source player.sh

declare -ag SPELL_REGISTRY=()

register_spell() {
    local spell_ref=$1
    local spell
    for spell in "${SPELL_REGISTRY[@]}"; do
        [[ "$spell" == "$spell_ref" ]] && return 1
    done
    SPELL_REGISTRY+=("$spell_ref")
}

save_spell_registry() {
    local file="save/spells/_registry.txt"
    mkdir -p "save/spells"
    {
        echo "# Registry of all spells"
        for spell_ref in "${SPELL_REGISTRY[@]}"; do
            echo "$spell_ref"
        done
    } > "$file"
}

load_spell_registry() {
    local file="save/spells/_registry.txt"
    SPELL_REGISTRY=()
    [[ ! -f "$file" ]] && return 0
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        [[ "$line" =~ ^# ]] && continue
        SPELL_REGISTRY+=("$line")
    done < "$file"
}

get_spell_name_from_scroll() {
    local scroll_name="$1"  # např. "Scroll of the Fire Bolt"
    echo "${scroll_name#Scroll of the }"
}

save_spellbook() {
    mkdir -p "save/spellbook"
    local spell_ref
    for spell_ref in "${SPELL_REGISTRY[@]}"; do
        obj_store "$spell_ref" "save/spellbook" "$spell_ref"
    done
}

load_spellbook() {
    mkdir -p "save/spellbook"
    local file spell_ref
    for file in save/spellbook/*; do
        [[ ! -f "$file" ]] && continue
        spell_ref=$(basename "$file")
        declare -gA "$spell_ref"
        register_spell "$spell_ref"
        obj_load "$spell_ref" "save/spellbook" "$spell_ref"
    done
}

get_spell_ref_by_name() {
    local search_name="$1"
    local spell_ref
    for spell_ref in "${SPELL_REGISTRY[@]}"; do
        local spell_name
        spell_name=$(obj_get "$spell_ref" "name")
        if [[ "$spell_name" == "$search_name" ]]; then
            echo "$spell_ref"
            return 0
        fi
    done
    return 1  # nenalezeno
}

get_spell_obj_ref() {
    local prefix=$1           # např. "spell"
    local used_ids=()
    local spell
    for spell in "${SPELL_REGISTRY[@]}"; do
        if [[ "$spell" =~ ^${prefix}spell([0-9]+)$ ]]; then
            used_ids+=("${BASH_REMATCH[1]}")
        fi
    done
    local id=1
    while :; do
        local found=0
        for used in "${used_ids[@]}"; do
            if (( 10#$used == id )); then
                found=1
                break
            fi
        done
        [[ $found -eq 0 ]] && break
        ((id++))
    done
    local spell_ref
    printf -v spell_ref "%sspell%03d" "$prefix" "$id"
    unset "$spell_ref"
    declare -gA "$spell_ref=()"
    assigned_spell_ref="$spell_ref"
}

use_scroll() {
    local item_ref="$1"
    local scroll_name spell_name spell_ref existing_ref value
    scroll_name=$(obj_get "$item_ref" "name")
    spell_name=$(get_spell_name_from_scroll "$scroll_name")
    existing_ref=$(get_spell_ref_by_name "$spell_name")
    if [[ -z "$existing_ref" ]]; then
        get_spell_obj_ref
        local spell_ref="$assigned_spell_ref"
        create_blank_object "$spell_ref"
        for prop in fire_damage_min fire_damage_max \
                    cold_damage_min cold_damage_max \
                    lightning_damage_min lightning_damage_max \
                    hp hp_max; do
            value=$(obj_get "$item_ref" "$prop")
            [[ -n "$value" && "$value" != "0" ]] && obj_set "$spell_ref" "$prop" "$value"
        done
        local mana=$(obj_get "$item_ref" "mana")
        obj_set "$spell_ref" "mana" "$mana"
        obj_set "$spell_ref" "name" "$spell_name"
        register_spell "$spell_ref"
        print_ui "" "You have learned the spell: $spell_name!"

    else
        local spell_ref="$existing_ref"
        local base_val add_val new_val
        for prop in fire_damage_min fire_damage_max \
                    cold_damage_min cold_damage_max \
                    lightning_damage_min lightning_damage_max \
                    hp_min hp_max; do
            base_val=$(obj_get "$spell_ref" "$prop")
            add_val=$(obj_get "$item_ref" "$prop")
            base_val=${base_val:-0}
            add_val=${add_val:-0}
            new_val=$(( base_val + add_val ))
            obj_set "$spell_ref" "$prop" "$new_val"
        done
        print_ui "" "Your spell $spell_name has become stronger!"
    fi
}

apply_spell() {
  local spell_ref=$1
  local npc_ref=$2
  [[ -z "$spell_ref" || -z "$npc_ref" ]] && return 1
  local player_mana=$(get_player_stat "mana")
  local spell_mana=$(obj_get "$spell_ref" "mana")
  if (( player_mana < spell_mana )); then
    print_ui "" "You don't have enough mana to cast this spell."
    return 1
  fi
  local new_mana=$(( player_mana - spell_mana ))
  set_player_stat "mana" "$new_mana"
  local spell_name
  spell_name=$(obj_get "$spell_ref" "name")
  local npc_name=$(obj_get "$npc_ref" "name")
  local total_damage=0
  local element
  local damage_min damage_max resist_val dmg
  for element in fire cold lightning; do
    damage_min=$(obj_get "$spell_ref" "${element}_damage_min")
    damage_max=$(obj_get "$spell_ref" "${element}_damage_max")
    [[ -z "$damage_min" || -z "$damage_max" || "$damage_max" == "0" ]] && continue
    local rand_damage=$(( damage_min + RANDOM % (damage_max - damage_min + 1) ))
    resist_val=$(obj_get "$npc_ref" "${element}_resist")
    [[ -z "$resist_val" ]] && resist_val=0
    dmg=$(( rand_damage * (100 - resist_val) / 100 ))
    (( total_damage += dmg ))
    #print_ui "" "${spell_name} hits ${npc_name} with ${element} damage: ${dmg}"
  done
  local heal_min heal_max
  heal_min=$(obj_get "$spell_ref" "hp_min")
  heal_max=$(obj_get "$spell_ref" "hp_max")
  if [[ -n "$heal_min" && "$heal_max" != "0" ]]; then
    local heal=$(( heal_min + RANDOM % (heal_max - heal_min + 1) ))
    local npc_hp npc_hp_max
    npc_hp=$(obj_get "$npc_ref" "hp")
    npc_hp_max=$(obj_get "$npc_ref" "hp_max")
    (( npc_hp += heal ))
    (( npc_hp > npc_hp_max )) && npc_hp=$npc_hp_max
    obj_set "$npc_ref" "hp" "$npc_hp"
    print_ui "" "${spell_name} heals ${npc_name} for ${heal} HP"
    return 0
  fi
  (( total_damage == 0 )) && return 0
  local npc_hp
  npc_hp=$(obj_get "$npc_ref" "hp")
  (( npc_hp -= total_damage ))
  obj_set "$npc_ref" "hp" "$npc_hp"
  print_ui "" "${npc_name} takes ${total_damage} damage from ${spell_name}!"
  if (( npc_hp <= 0 )); then
    print_ui "" "${npc_name} was slain by ${spell_name}!"
    kill "$npc_ref"
  fi
  return 0
}

