#!/bin/bash
source object.sh
source npc.sh
source ui.sh
source item.sh
source map.sh
source player.sh
source casting.sh

VERSION="v1.1.0"

save_game() {
  mkdir -p save
  mkdir -p save/inventory
  save_spellbook
  save_items
  save_npcs
  save_portals
  save_inventory
  save_player
  save_map_registry
  stty "$STTY_SAVE"
  clear
  exit
}

trap save_game INT TERM EXIT

load_game() {
  if [[ ! -d "save" ]]; then
        local msg="No saved game found."
        local row=$((TERM_HEIGHT / 2))
        local col=$(( (TERM_WIDTH - ${#msg}) / 2 ))
        clear
        echo -ne "\e[H"
        echo -ne "\e[$((row+1));$((col+1))H"
        echo "$msg"
        read_key
        return 1
    fi
  load_spellbook
  load_player
  load_npcs
  load_items
  load_portals
  load_inventory
  load_map_registry
  local map=$(get_player_stat "map")
  map_load "$map"
}

start_new_game() {
  new_player
  clear
  echo "Generating overworld..."
  generate_overworld
  local base_x=750
local base_y=750
local x y
local tries=200
while ((tries > 0)); do
    if ((tries == 200)); then
        x=$base_x
        y=$base_y
    else
       x=$((base_x + (RANDOM % 41) - 20))                                                      y=$((base_y + (RANDOM % 41) - 20))
    fi
    if is_space_free "$x" "$y"; then
        set_player_stat "x" "$x"
        set_player_stat "y" "$y"
        set_player_stat "safe_map" "overworld"
        set_player_stat "safe_x" "$x"
        set_player_stat "safe_y" "$y"
        set_player_stat "safe_subtype" 4
        set_player_stat "safe_location" "overworld"
        break
    fi
    ((tries--))
done
}

new_game() {
  local highlight="\e[47;30m"
  local normal="\e[0m"
  local options=("Yes" "No")
  local selected=0
  local key=""
  local term_rows=${LINES:-24}
  local term_cols=${COLUMNS:-80}
  echo -ne "\e[?25l" # skryj kurzor
  trap 'echo -ne "\e[?25h"' EXIT
  move_cursor() {
    echo -ne "\e[${1};${2}H"
  }
  draw_prompt() {
    echo -ne "\e[2J" # clear screen
    local text="A save already exists. Do you want to start a new game?"
    local text_y=$((TERM_HEIGHT / 2 - 1))
    local text_x=$((TERM_WIDTH / 2 - ${#text} / 2))
    move_cursor "$text_y" "$text_x"
    echo -ne "\e[96m${text}\e[0m"
    for i in "${!options[@]}"; do
      local option="${options[$i]}"
      local opt_x=$((TERM_WIDTH / 2 - 5 + i * 10))
      local opt_y=$((TERM_HEIGHT / 2 + 2))
      move_cursor "$opt_y" "$opt_x"
      if [[ $i -eq $selected ]]; then
        echo -ne "${highlight}${option}${normal}"
      else
        echo -ne "${normal}${option}${normal}"
      fi
    done
    move_cursor $TERM_HEIGHT 1
  }

  if [[ ! -d save ]]; then
    start_new_game
    return
  fi
  while true; do
    draw_prompt
    read -rsn1 key
    case "$key" in
      $'\x1b') # escape sekvence
        read -rsn2 key
        case "$key" in
          "[C") ((selected++)) ;; # šipka doprava
          "[D") ((selected--)) ;; # šipka doleva
        esac
        ;;
      "") # Enter
        case $selected in
          0)
            echo -ne "\e[2J"
            rm -r save
            start_new_game
            return
            ;;
          1)
            echo -ne "\e[2J"
            show_intro_menu
            return
            ;;
        esac
        ;;
    esac
    ((selected < 0)) && selected=$((${#options[@]} - 1))
    ((selected >= ${#options[@]})) && selected=0
  done
}

get() {
  local px py
  px=$(get_player_stat "x")
  py=$(get_player_stat "y")
  local item_ref
  item_ref=$(item_on_xy "$px" "$py")
  if [[ -z "$item_ref" ]]; then
    print_ui "" "There is no item on the ground."
    return
  fi
  local subtype=$(obj_get "$item_ref" "subtype")
  if [[ "$subtype"  == "9" ]]; then
  local coins=$(obj_get "$item_ref" "value")
    print_ui "" "Your picked up $coins coins."
    local gold=$(get_player_stat "gold")
    local new_gold=$(( gold + coins ))
    set_player_stat "gold" "$new_gold"
    destroy_item "$item_ref"
    return
  fi
  local slot_found=0
  for i in {1..8}; do
    local slot_name="inventory${i}"
    local slot_value
    slot_value=$(obj_get "player_ref" "$slot_name")
    if [[ -z "$slot_value" ]]; then
      obj_set "player_ref" "$slot_name" "$item_ref"
      obj_set "$item_ref" "in_inventory" 1
      local item_name
      item_name=$(obj_get "$item_ref" "name")
      print_ui "" "You picked up $item_name."
      slot_found=1
      break
    fi
  done
  if ((slot_found == 0)); then
    print_ui "" "Your inventory is full."
  fi
}

drop() {
  local slot=$1
  if [[ -z "$slot" || "$slot" -lt 1 || "$slot" -gt 8 ]]; then
    print_ui "" "Invalid inventory slot."
    return
  fi
  local slot_name="inventory${slot}"
  local item_ref
  item_ref=$(obj_get "player_ref" "$slot_name")
  if [[ -z "$item_ref" ]]; then
    print_ui "" "There is nothing to drop."
    return
  fi
  local px py
  px=$(get_player_stat "x")
  py=$(get_player_stat "y")
  local existing
  existing=$(item_on_xy "$px" "$py")
  if [[ -n "$existing" ]]; then
    print_ui "" "You can’t drop that here."
    return
  fi
  obj_set "$item_ref" "x" "$px"
  obj_set "$item_ref" "y" "$py"
  obj_set "$item_ref" "in_inventory" 0
  obj_set "player_ref" "$slot_name" ""
  local item_name
  item_name=$(obj_get "$item_ref" "name")
  print_ui "" "You dropped $item_name."
}

use() {
  local item_ref=$1
  if [[ -z "$item_ref" ]]; then
    print_ui "" "No item to use."
    return
  fi
  local subtype
  subtype=$(obj_get "$item_ref" "subtype")
  case "$subtype" in
    0 | 1 | 2 | 3 | 4 | 5)
      print_ui "" "You can’t use this item directly."
      return
      ;;
    6) # healing potion
      local hp hp_max heal
      hp=$(get_player_stat "hp")
      hp_max=$(get_player_stat "hp_max")
      heal=$(obj_get "$item_ref" "hp")
      ((hp += heal))
      ((hp > hp_max)) && hp=$hp_max
      set_player_stat "hp" "$hp"
      print_ui "" "You drink a healing potion and feel restored."
      destroy_item_abs "$item_ref"
      ;;
    7) # mana potion
      local mana mana_max restore
      mana=$(get_player_stat "mana")
      mana_max=$(get_player_stat "mana_max")
      restore=$(obj_get "$item_ref" "mana")
      ((mana += restore))
      ((mana > mana_max)) && mana=$mana_max
      set_player_stat "mana" "$mana"
      print_ui "" "You drink a mana potion and regain magical energy."
      destroy_item_abs "$item_ref"
      ;;
    8) # food
      local hp mana hp_max mana_max heal restore
      hp=$(get_player_stat "hp")
      mana=$(get_player_stat "mana")
      hp_max=$(get_player_stat "hp_max")
      mana_max=$(get_player_stat "mana_max")
      heal=$(obj_get "$item_ref" "hp")
      restore=$(obj_get "$item_ref" "mana")
      ((hp += heal))
      ((mana += restore))
      ((hp > hp_max)) && hp=$hp_max
      ((mana > mana_max)) && mana=$mana_max
      set_player_stat "hp" "$hp"
      set_player_stat "mana" "$mana"
      print_ui "" "You eat the food and feel nourished."
      destroy_item_abs "$item_ref"
      ;;
    10)
     use_scroll "$item_ref"
     destroy_item_abs "$item_ref":
      ;;
    *)
      print_ui "" "This item cannot be used."
      ;;
  esac
}

use_potion() {
  local potion_num=$1
  if [[ -z "$potion_num" ]]; then
    print_ui "" "No potion slot specified."
    return
  fi
  local slot_name="potion${potion_num}"
  local potion_ref
  potion_ref=$(obj_get "player_ref" "$slot_name")
  if [[ -z "$potion_ref" ]]; then
    print_ui "" "There is no potion in that slot."
    return
  fi
  local subtype
  subtype=$(obj_get "$potion_ref" "subtype")
  if [[ "$subtype" -ne 6 && "$subtype" -ne 7 ]]; then
    print_ui "" "That is not a potion."
    return
  fi
  use "$potion_ref"
  obj_set "player_ref" "$slot_name" ""
}

rest() {
  local nearby
  nearby=$(monsters_in_viewport)
  if [[ -n "$nearby" ]]; then
    print_ui "" "You cannot rest while monsters are nearby!"
    return
  fi
  local hp mana hp_max mana_max
  hp=$(get_player_stat "hp")
  mana=$(get_player_stat "mana")
  hp_max=$(get_player_stat "hp_max")
  mana_max=$(get_player_stat "mana_max")
  for i in {1..8}; do
    local slot="inventory${i}"
    local item_ref
    item_ref=$(get_player_stat "$slot")
    [[ -z "$item_ref" ]] && continue
    local subtype
    subtype=$(obj_get "$item_ref" "subtype")
    if [[ "$subtype" -eq 8 ]]; then
      local food_hp food_mana
      food_hp=$(obj_get "$item_ref" "hp")
      food_mana=$(obj_get "$item_ref" "mana")
      ((hp += food_hp * 2))
      ((mana += food_mana * 2))
      ((hp > hp_max)) && hp=$hp_max
      ((mana > mana_max)) && mana=$mana_max
      set_player_stat "hp" "$hp"
      set_player_stat "mana" "$mana"
      local item_name
      item_name=$(obj_get "$item_ref" "name")
      print_ui "" "You rest and eat $item_name."
      set_player_stat "$slot" ""
      destroy_item_abs "$item_ref"
      return
    fi
  done
  print_ui "" "You have no food to rest."
}

enter() {
  check_portal
}

main_loop() {
  show_intro_menu
  STTY_SAVE=$(stty -g)
  stty -echo -icanon time 0 min 0
  show_help
  PLAYER_X=$(get_player_stat "x")
  PLAYER_Y=$(get_player_stat "y")
  draw_interface
  draw
  while true; do
    key=$(read_key)
    case "$key" in
      $'\x1b[A') move_up ;;
      $'\x1b[B') move_down ;;
      $'\x1b[C') move_right ;;
      $'\x1b[D') move_left ;;
      q) save_game ;;
      i) show_inventory ;;
      s) show_stats ;;
      g) get ;;
      1) use_potion 1 ;;
      2) use_potion 2 ;;
      3) use_potion 3 ;;
      4) use_potion 4 ;;
      m) show_main_menu ;;
      r) rest ;;
      h) show_help ;;
      e) enter ;;
      c) cast ;;
    esac
    PLAYER_X="${player_ref[x]}"
    PLAYER_Y="${player_ref[y]}"
    drive_poison
    drive_npcs
    destroy_hidden_items
    draw_interface
    draw
  done
}

main_loop
