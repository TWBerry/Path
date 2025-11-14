[[ -n "${_UI_SH_INCLUDED:-}" ]] && return
_UI_SH_INCLUDED=1
source object.sh
source item.sh
source npc.sh
source player.sh
source map.sh

UI_COLOR_RESET="\e[0m"
UI_COLOR_RED="\e[31m"
UI_COLOR_GREEN="\e[32m"
UI_COLOR_YELLOW="\e[33m"
UI_COLOR_BLUE="\e[34m"
UI_COLOR_MAGENTA="\e[35m"
UI_COLOR_CYAN="\e[36m"
UI_COLOR_WHITE="\e[37m"

get_terminal_size() {
  local rows cols
  read -r rows cols < <(stty size 2>/dev/null || echo "24 80")
  TERM_HEIGHT="$rows"
  TERM_WIDTH="$cols"
}

get_terminal_size
VIEWPORT_X=1
VIEWPORT_Y=1
VIEWPORT_HEIGHT=$((TERM_HEIGHT - 9))
VIEWPORT_WIDTH=$((TERM_WIDTH - 8))
center_x=$((VIEWPORT_WIDTH / 2))
center_y=$((VIEWPORT_HEIGHT / 2))

read_key() {
  IFS= read -rsn1 key 2>/dev/null || key=''

  if [[ $key == $'\x1b' ]]; then
    IFS= read -rsn1 -t 0.001 k1 2>/dev/null || k1=''
    IFS= read -rsn1 -t 0.001 k2 2>/dev/null || k2=''
    key+="$k1$k2"
  fi
  printf '%s' "$key"
}

declare -Ag FRAME_BUFFER=()

clear_frame_buffer() {
  unset FRAME_BUFFER
  declare -gA FRAME_BUFFER=()
}

draw_vertical_bar() {
  local x=$1
  local y=$2
  local height=$3
  local value=$4
  local max_value=$5
  local color=$6
  local filled=$((value * height / max_value))
  for ((i = 0; i < height; i++)); do
    local char=" "
    if ((i < filled)); then
      char="█"
    fi
    FRAME_BUFFER["$x,$((y - i))"]="${color}${char}"
  done
}

plot() {
  local x=$1
  local y=$2
  local ch=$3
  local color=$4
  FRAME_BUFFER["$x,$y"]="${color}${ch}"
}

h_line() {
  local x1=$1
  local y=$2
  local x2=$3
  local color="${4:-}"
  ((x1 > x2)) && {
    local tmp=$x1
    x1=$x2
    x2=$tmp
  }
  for ((x = x1; x <= x2; x++)); do
  FRAME_BUFFER["$x,$y"]="${color}#"
  done
}

v_line() {
  local x=$1
  local y1=$2
  local y2=$3
  local color="${4:-}"
  ((y1 > y2)) && {
    local tmp=$y1
    y1=$y2
    y2=$tmp
  }
  for ((y = y1; y <= y2; y++)); do
    FRAME_BUFFER["$x,$y"]="${color}#"
  done
}

draw_box() {
  local x1=$1
  local y1=$2
  local x2=$3
  local y2=$4
  local color="${5:-}"
  h_line "$x1" "$y1" "$x2" "$color"
  h_line "$x1" "$y2" "$x2" "$color"
  v_line "$x1" "$y1" "$y2" "$color"
  v_line "$x2" "$y1" "$y2" "$color"
  plot "$x1" "$y1" "#" "$color"
  plot "$x2" "$y1" "#" "$color"
  plot "$x1" "$y2" "#" "$color"
  plot "$x2" "$y2" "#" "$color"
}
declare -ag UI_LOG_LINES=()
UI_LOG_MAX=5
UI_LOG_WIDTH=$((TERM_WIDTH - 9))

print_ui() {
  local color="$1"
  local msg="$2"
  for ((i = 0; i < UI_LOG_MAX - 1; i++)); do
    UI_LOG_LINES[i]="${UI_LOG_LINES[i + 1]}"
  done
  UI_LOG_LINES[UI_LOG_MAX - 1]="$msg"
}

in_viewport() {
   local x=$1
  local y=$2
  local px py
  px=$PLAYER_X
  py=$PLAYER_Y
  local half_width=$((VIEWPORT_WIDTH / 2))
  local half_height=$((VIEWPORT_HEIGHT / 2))
  local min_x=$((px - half_width))
  local max_x=$((px + half_width))
  local min_y=$((py - half_height))
  local max_y=$((py + half_height))
  if ((x >= min_x && x <= max_x && y >= min_y && y <= max_y)); then
    return 0
  else
    return 1
  fi
}

get_viewx() {
  local x=$1
  echo $((x - PLAYER_X + VIEWPORT_WIDTH / 2))
}

get_viewy() {
  local y=$1
  echo $((y - PLAYER_Y + VIEWPORT_HEIGHT / 2))
}

draw_potions() {
    declare -n PLAYER="player_ref"
    local y1=$((TERM_HEIGHT - UI_LOG_MAX - 3))
    local y_slots=$((TERM_HEIGHT - UI_LOG_MAX - 3))
    local start_x=1
    h_line 0 "$y1" $((TERM_WIDTH - 8))
    for ((i = 1; i <= 4; i++)); do
        local key="potion$i"
        local potion="${PLAYER[$key]}"
        local color="\033[40m"
        local ch="$i"

        if [[ -n "$potion" ]]; then
            declare -n P="$potion"
            case "${P[subtype]}" in
                6) color="\033[41m" ;; # HP potion
                7) color="\033[44m" ;; # Mana potion
            esac
        fi
        local x_pos=$((start_x + (i - 1) * 2))
        FRAME_BUFFER["$x_pos,$y_slots"]="${color}${ch}\e[0m"
    done
}

print_ui_draw() {
local base_y=$((TERM_HEIGHT - UI_LOG_MAX - 1))
    local i j line char y idx
    for ((i = 0; i < UI_LOG_MAX; i++)); do
        line="${UI_LOG_LINES[i]}"
         printf -v line "%-${UI_LOG_WIDTH}s" "$line"
        y=$((base_y + i))
        for ((j = 0; j < UI_LOG_WIDTH; j++)); do
            char=${line:j:1}
            idx="$((j + 1)),$y"
            FRAME_BUFFER["$idx"]="$char"
        done
    done
}

draw_interface() {
    clear_frame_buffer
    map_render_to_buffer
    draw_box 0 0 $((TERM_WIDTH - 1)) $((TERM_HEIGHT - 1)) "\e[37m"
    local hp_color="\033[31m"  # default red
    [[ "${player_ref[poisoned]}" == "true" ]] && hp_color="\033[32m"
    draw_vertical_bar $((TERM_WIDTH - 6)) $((TERM_HEIGHT - 2)) \
        $((TERM_HEIGHT - 2)) \
        "${player_ref[hp]}" "${player_ref[hp_max]}" "$hp_color"
    draw_vertical_bar $((TERM_WIDTH - 4)) $((TERM_HEIGHT - 2)) \
        $((TERM_HEIGHT - 2)) \
        "${player_ref[mana]}" "${player_ref[mana_max]}" "\033[34m"
    local curr_exp="${player_ref[experience]}"
    local max_exp="${player_ref[next_level_exp]}"
    local prev_exp="${player_ref[prev_level_exp]}"
    local rel_exp=$((curr_exp - prev_exp))
    max_exp=$((max_exp - prev_exp))
    draw_vertical_bar $((TERM_WIDTH - 2)) $((TERM_HEIGHT - 2)) \
        $((TERM_HEIGHT - 2)) \
        "$rel_exp" "$max_exp" "\033[33m"
    v_line $((TERM_WIDTH - 8)) 1 $((TERM_HEIGHT - 1)) "\e[37m"
    h_line 0 $((TERM_HEIGHT - UI_LOG_MAX - 2)) $((TERM_WIDTH - 8)) "\e[37m"
    local base_y=$((TERM_HEIGHT - UI_LOG_MAX - 1))
    local i j line char y idx
    for ((i = 0; i < UI_LOG_MAX; i++)); do
        line="${UI_LOG_LINES[i]}"
        printf -v line "%-${UI_LOG_WIDTH}s" "$line"
        y=$((base_y + i))
        for ((j = 0; j < UI_LOG_WIDTH; j++)); do
            char=${line:j:1}
            idx="$((j + 1)),$y"
            FRAME_BUFFER["$idx"]="$char"
        done
    done
    draw_potions
    local line vx vy icon
    while IFS=';' read -r vx vy icon; do
      FRAME_BUFFER["$vx,$vy"]="\e[37m${icon}"
    done < <(iterate_over_portals_par "draw_portal" "$PLAYER_X" "$PLAYER_Y")
    local bg fg
    while IFS=';' read -r vx vy icon bg fg; do
      FRAME_BUFFER["$vx,$vy"]="\e[${bg};${fg}m${icon}\e[0m"
    done < <(iterate_over_items_par "draw_item" "$PLAYER_X" "$PLAYER_Y")
    while IFS=';' read -r vx vy icon bg fg; do
      FRAME_BUFFER["$vx,$vy"]="\e[${bg};${fg}m${icon}\e[0m"
    done < <(iterate_over_npc_par "draw_npc" "$PLAYER_X" "$PLAYER_Y")
    FRAME_BUFFER["$center_x,$center_y"]="\e[36m@"
}

draw() {
  printf "\033[?25l"
  printf "\033[H"
  local max_x=$((TERM_WIDTH - 1))
  local max_y=$((TERM_HEIGHT - 1))
  for ((y = 0; y <= max_y; y++)); do
    local line=""
    for ((x = 0; x <= max_x; x++)); do
      if [[ -n "${FRAME_BUFFER[$x,$y]}" ]]; then
        line+="${FRAME_BUFFER[$x,$y]}"
      else
        line+=" "
      fi
    done
    if ((y < max_y)); then
      printf "%b\033[0m\n" "${line//\\e/$'\e'}"
    else
      printf "%b\033[0m" "${line//\\e/$'\e'}"
    fi
  done
}

plot_inv() {
  local x=$1
  local y=$2
  local text=$3
  local color="${4:-}"
  local i
  for ((i = 0; i < ${#text}; i++)); do
    local ch="${text:i:1}"
    FRAME_BUFFER["$((x + i)),$y"]="${color}${ch}\033[0m"
  done
}

equip_from_inventory() {
  local slot_num=$1
  local slot_name="inventory${slot_num}"
  local item_ref
  item_ref=$(obj_get "player_ref" "$slot_name")
  if [[ -z "$item_ref" ]]; then
    print_ui "" "No item in this slot."
    return
  fi
  local subtype
  subtype=$(obj_get "$item_ref" "subtype")
  local item_name
  item_name=$(obj_get "$item_ref" "name")
  if ((subtype >= 0 && subtype <= 5)); then
    local equip_slot=""
    case $subtype in
      0) equip_slot="weapon" ;;
      1) equip_slot="shield" ;;
      2) equip_slot="helmet" ;;
      3) equip_slot="armor" ;;
      4) equip_slot="amulet" ;;
      5) equip_slot="ring" ;;
    esac
    local old_item
    old_item=$(get_player_stat "$equip_slot")
    if [[ -n "$old_item" ]]; then
      local moved=0
      for i in {1..8}; do
        local inv_slot="inventory${i}"
        local val
        val=$(obj_get "player_ref" "$inv_slot")
        if [[ -z "$val" ]]; then
          obj_set "player_ref" "$inv_slot" "$old_item"
          obj_set "$old_item" "in_inventory" 1
          obj_set "$old_item" "equiped" 0
          moved=1
          break
        fi
      done
      if ((moved == 0)); then
        print_ui "" "Inventory is full! Can't unequip current item."
        return
      fi
    fi
    obj_set "player_ref" "$equip_slot" "$item_ref"
    obj_set "$item_ref" "equiped" 1
    obj_set "$item_ref" "in_inventory" 0
    obj_set "player_ref" "$slot_name" ""
    print_ui "" "You equipped $item_name."
    return
  fi
  if ((subtype == 6 || subtype == 7)); then
    local placed=0
    for i in {1..4}; do
      local pslot="potion${i}"
      local val
      val=$(get_player_stat "$pslot")
      if [[ -z "$val" ]]; then
        set_player_stat "$pslot" "$item_ref"
        obj_set "$item_ref" "equiped" 1
        obj_set "$item_ref" "in_inventory" 0
        obj_set "player_ref" "$slot_name" ""
        print_ui "" "You placed $item_name into potion slot $i."
        placed=1
        break
      fi
    done
    if ((placed == 0)); then
      print_ui "" "All potion slots are full."
    fi
    return
  fi
  if ((subtype == 8)); then
    print_ui "" "You can’t equip food."
    return
  fi
  print_ui "" "You can’t equip this item."
}

use_from_inventory() {
  local slot_num=$1
  local slot_name="inventory${slot_num}"
  local item_ref
  item_ref=$(obj_get "player_ref" "$slot_name")
  if [[ -z "$item_ref" ]]; then
    print_ui "" "No item in this slot."
    return
  fi
  local subtype
  subtype=$(obj_get "$item_ref" "subtype")
  local item_name
  item_name=$(obj_get "$item_ref" "name")
  if ((subtype == 6 || subtype == 7 || subtype == 8 || subtype == 10)); then
    use "$item_ref"
    obj_set "player_ref" "$slot_name" ""
    print_ui "" "You used $item_name."
  else
    print_ui "" "You can’t use this item."
  fi
}

render_stats_comparison() {
  local base_ref=$1
  local compare_ref=$2
  local x=$3
  local line_y2=$4
  local stats=(hp hp_max hp_min mana strength vitality energy dexterity defense min_damage max_damage fire_resistence cold_resistence poison_resistence lightning_resistence block_rate fire_damage_min fire_damage_max cold_damage_min cold_damage_max poison_damage poison_damage_time lightning_damage_min lightning_damage_max)
  for stat in "${stats[@]}"; do
    if [[ "$stat" =~ _max$ ]]; then
      continue
    fi
    if [[ "$stat" =~ _min$ ]]; then
      local base="${stat%_min}"
      local min1=$(obj_get "$base_ref" "${base}_min")
      local max1=$(obj_get "$base_ref" "${base}_max")
      local min2=0
      local max2=0
      if [[ -n "$compare_ref" ]]; then
        min2=$(obj_get "$compare_ref" "${base}_min")
        max2=$(obj_get "$compare_ref" "${base}_max")
      fi
      if ((min1 == 0 && max1 == 0 && min2 == 0 && max2 == 0)); then
        continue
      fi
      local color="\033[0m"
      if ((min2 != 0 || max2 != 0)); then
        if ((min1 > min2 || max1 > max2)); then
          color="\033[32m"
        elif ((min1 < min2 || max1 < max2)); then
          color="\033[31m"
        fi
      fi
      plot_inv "$x" "$((line_y2++))" "$(printf '%-20s %s - %s' "$base" "$min1" "$max1")" "$color"
    else
      local val1=$(obj_get "$base_ref" "$stat")
      local val2=0
      if [[ -n "$compare_ref" ]]; then
        val2=$(obj_get "$compare_ref" "$stat")
      fi
      if ((val1 == 0 && val2 == 0)); then
        continue
      fi
      local color="\033[0m"
      if ((val2 != 0)); then
        if ((val1 > val2)); then
          color="\033[32m"
        elif ((val1 < val2)); then
          color="\033[31m"
        fi
      fi
      plot_inv "$x" "$((line_y2++))" "$(printf '%-20s %s' "$stat" "$val1")" "$color"
    fi
  done
  local val1=$(obj_get "$base_ref" "value")
  local val2=0
  if [[ -n "$compare_ref" ]]; then
      val2=$(obj_get "$compare_ref" "value")
  fi
  if ((val1 != 0 || val2 != 0)); then
      local color="\033[0m"
      if ((val2 != 0)); then
          if ((val1 > val2)); then
              color="\033[32m"
          elif ((val1 < val2)); then
              color="\033[31m"
          fi
      fi
      plot_inv "$x" "$((line_y2++))" "$(printf '%-20s %s' "value" "$val1")" "$color"
  fi
  newline=$line_y2
}

show_inventory() {
  clear_frame_buffer
  draw_box 0 0 $((TERM_WIDTH - 1)) $((TERM_HEIGHT - 1))
  v_line $((TERM_WIDTH - 36)) 1 $((TERM_HEIGHT - 2))
  h_line 0 $((TERM_HEIGHT - UI_LOG_MAX - 2)) $((TERM_WIDTH - 1))
  print_ui_draw
  draw
  local selected=1
  local key=""
  local max_slots=8
  while true; do
    clear_frame_buffer
    draw_box 0 0 $((TERM_WIDTH - 1)) $((TERM_HEIGHT - 1))
    v_line $((TERM_WIDTH - 36)) 1 $((TERM_HEIGHT - 2))
    h_line 0 $((TERM_HEIGHT - UI_LOG_MAX - 2)) $((TERM_WIDTH - 1))
    local y_offset=2
    for i in $(seq 1 $max_slots); do
      local slot_name="inventory${i}"
      local item_ref
      item_ref=$(obj_get "player_ref" "$slot_name")
      local line_y=$((y_offset + i - 1))
      if [[ -n "$item_ref" ]]; then
        local item_name
        item_name=$(obj_get "$item_ref" "name")
        if ((i == selected)); then
          plot_inv $((TERM_WIDTH - 34)) "$line_y" "[$i] $item_name" "\033[1;30;47m"
        else
          plot_inv $((TERM_WIDTH - 34)) "$line_y" "[$i] $item_name"
        fi
      else
        local text="[$i] (empty)"
        if ((i == selected)); then
          plot_inv $((TERM_WIDTH - 34)) "$line_y" "$text" "\033[1;30;47m"
        else
          plot_inv $((TERM_WIDTH - 34)) "$line_y" "$text"
        fi
      fi
    done
    local slot_name="inventory${selected}"
    local item_ref
    item_ref=$(obj_get "player_ref" "$slot_name")
    if [[ -n "$item_ref" ]]; then
      local subtype
      subtype=$(obj_get "$item_ref" "subtype")
      local line_y=2
      plot_inv 2 $((line_y++)) "Item: $(obj_get "$item_ref" "name")" "\033[1m"
      plot_inv 2 $((line_y++)) "--------------------"
      local equip_slot=""
      case "$subtype" in
        0) equip_slot="weapon" ;;
        1) equip_slot="shield" ;;
        2) equip_slot="helmet" ;;
        3) equip_slot="armor" ;;
        4) equip_slot="amulet" ;;
        5) equip_slot="ring" ;;
      esac
      local equipped_ref=""
      if [[ -n "$equip_slot" ]]; then
        equipped_ref=$(get_player_stat "$equip_slot")
      fi
      render_stats_comparison "$item_ref" "$equipped_ref" 2 line_y
      if [[ "$equipped_ref" != "" ]]; then
        ((newline++))
        plot_inv 2 $((newline++)) "--- Equipped ----"
        render_stats_comparison "$equipped_ref" "$item_ref" 2 newline
      fi
    else
      plot_inv 2 2 "Empty slot selected." "\033[2m"
    fi
    local gold
    gold=$(get_player_stat "gold")
    plot_inv 2 "$((TERM_HEIGHT - UI_LOG_MAX - 3))" "Gold: $gold"
    print_ui_draw
    draw
    key=$(read_key)
    case "$key" in
      $'\x1b[A') ((selected > 1)) && ((selected--)) ;;
      $'\x1b[B') ((selected < max_slots)) && ((selected++)) ;;
      e) equip_from_inventory "$selected" ;;
      u) use_from_inventory "$selected" ;;
      d) drop "$selected" ;;
      q | $'\x1b') break ;;
    esac
  done
  draw
}

buy() {
    local npc_ref="$1"
    clear_frame_buffer
    draw_box 0 0 $((TERM_WIDTH - 1)) $((TERM_HEIGHT - 1))
    v_line $((TERM_WIDTH - 36)) 1 $((TERM_HEIGHT - 2))
    h_line 0 $((TERM_HEIGHT - UI_LOG_MAX - 2)) $((TERM_WIDTH - 1))
    print_ui_draw
    draw
    local selected=1
    local key=""
    local max_slots=8
    while true; do
        clear_frame_buffer
        draw_box 0 0 $((TERM_WIDTH - 1)) $((TERM_HEIGHT - 1))
        v_line $((TERM_WIDTH - 36)) 1 $((TERM_HEIGHT - 2))
        h_line 0 $((TERM_HEIGHT - UI_LOG_MAX - 2)) $((TERM_WIDTH - 1))
        local y_offset=2
        for i in $(seq 1 $max_slots); do
            local slot="inventory$i"
            local item_ref
            item_ref=$(obj_get "$npc_ref" "$slot")
            local line_y=$((y_offset + i - 1))
            if [[ -n "$item_ref" ]]; then
                local item_name
                item_name=$(obj_get "$item_ref" "name")
                local item_val
                item_val=$(obj_get "$item_ref" "value")
                if ((i == selected)); then
                    plot_inv $((TERM_WIDTH - 34)) "$line_y" \
                        "[$i] $item_name ($item_val g)" "\033[1;30;47m"
                else
                    plot_inv $((TERM_WIDTH - 34)) "$line_y" \
                        "[$i] $item_name ($item_val g)"
                fi
            else
                local text="[$i] (empty)"
                if ((i == selected)); then
                    plot_inv $((TERM_WIDTH - 34)) "$line_y" "$text" "\033[1;30;47m"
                else
                    plot_inv $((TERM_WIDTH - 34)) "$line_y" "$text"
                fi
            fi
        done
        local slot_name="inventory${selected}"
    local item_ref
    item_ref=$(obj_get "$npc_ref" "$slot_name")
    if [[ -n "$item_ref" ]]; then
      local item_name item_value subtype
      item_name=$(obj_get "$item_ref" "name")
      item_value=$(obj_get "$item_ref" "value")
      subtype=$(obj_get "$item_ref" "subtype")
      local line_y=2
      plot_inv 2 $((line_y++)) "Item: $item_name" "\033[1m"
      plot_inv 2 $((line_y++)) "Value: ${item_val} g"
      plot_inv 2 $((line_y++)) "----------------------"
      render_stats_comparison "$item_ref" "" 2 line_y
    else
      plot_inv 2 2 "Empty slot selected." "\033[2m"
    fi
        local gold
        gold=$(get_player_stat "gold")
        plot_inv 2 "$((TERM_HEIGHT - UI_LOG_MAX - 3))" "Your Gold: $gold g"
        print_ui_draw
        draw
        key=$(read_key)
        case "$key" in
            $'\x1b[A') ((selected > 1)) && ((selected--)) ;;
            $'\x1b[B') ((selected < max_slots)) && ((selected++)) ;;
            b)
                local slot="inventory$selected"
                local item_ref
                item_ref=$(obj_get "$npc_ref" "$slot")
                if [[ -z "$item_ref" ]]; then
                    print_ui "" "Nothing is for sale in that slot."
                    continue
                fi
                local price
                price=$(obj_get "$item_ref" "value")
                if (( gold < price )); then
                    print_ui "" "You do not have enough gold!"
                    continue
                fi
                local dest_slot=""
                for i in $(seq 1 $max_slots); do
                    local pslot="inventory$i"
                    local test_ref
                    test_ref=$(obj_get "player_ref" "$pslot")
                    if [[ -z "$test_ref" ]]; then
                        dest_slot="$pslot"
                        break
                    fi
                done
                if [[ -z "$dest_slot" ]]; then
                    print_ui "" "Your inventory is full!"
                    continue
                fi
                set_player_stat "gold" $(( gold - price ))
                obj_set "player_ref" "$dest_slot" "$item_ref"
                obj_set "$npc_ref" "$slot" ""
                obj_set "$item_ref" "in_npc_inv" 0
                print_ui "" "You bought $(obj_get "$item_ref" "name")."
                ;;
            q | $'\x1b')
                break ;;
        esac
    done
    draw
}

sell() {
  clear_frame_buffer
  draw_box 0 0 $((TERM_WIDTH - 1)) $((TERM_HEIGHT - 1))
  v_line $((TERM_WIDTH - 36)) 1 $((TERM_HEIGHT - 2))
  h_line 0 $((TERM_HEIGHT - UI_LOG_MAX - 2)) $((TERM_WIDTH - 1))
  print_ui_draw
  draw
  local selected=1
  local key=""
  local max_slots=8
  while true; do
    clear_frame_buffer
    draw_box 0 0 $((TERM_WIDTH - 1)) $((TERM_HEIGHT - 1))
    v_line $((TERM_WIDTH - 36)) 1 $((TERM_HEIGHT - 2))
    h_line 0 $((TERM_HEIGHT - UI_LOG_MAX - 2)) $((TERM_WIDTH - 1))
    local y_offset=2
    for i in $(seq 1 $max_slots); do
      local slot_name="inventory${i}"
      local item_ref
      item_ref=$(obj_get "player_ref" "$slot_name")
      local line_y=$((y_offset + i - 1))
      if [[ -n "$item_ref" ]]; then
        local item_name
        item_name=$(obj_get "$item_ref" "name")
        if ((i == selected)); then
          plot_inv $((TERM_WIDTH - 34)) "$line_y" "[$i] $item_name" "\033[1;30;47m"
        else
          plot_inv $((TERM_WIDTH - 34)) "$line_y" "[$i] $item_name"
        fi
      else
        local text="[$i] (empty)"
        if ((i == selected)); then
          plot_inv $((TERM_WIDTH - 34)) "$line_y" "$text" "\033[1;30;47m"
        else
          plot_inv $((TERM_WIDTH - 34)) "$line_y" "$text"
        fi
      fi
    done
    local slot_name="inventory${selected}"
    local item_ref
    item_ref=$(obj_get "player_ref" "$slot_name")
    if [[ -n "$item_ref" ]]; then
      local item_name item_value subtype
      item_name=$(obj_get "$item_ref" "name")
      item_value=$(obj_get "$item_ref" "value")
      subtype=$(obj_get "$item_ref" "subtype")
      local line_y=2
      plot_inv 2 $((line_y++)) "Item: $item_name" "\033[1m"
      plot_inv 2 $((line_y++)) "Value: ${item_value}g"
      plot_inv 2 $((line_y++)) "----------------------"
      render_stats_comparison "$item_ref" "" 2 line_y
    else
      plot_inv 2 2 "Empty slot selected." "\033[2m"
    fi
    local gold
    gold=$(get_player_stat "gold")
    plot_inv 2 "$((TERM_HEIGHT - UI_LOG_MAX - 3))" "Gold: $gold"
    print_ui_draw
    draw
    key=$(read_key)
    case "$key" in
      $'\x1b[A') ((selected > 1)) && ((selected--)) ;;
      $'\x1b[B') ((selected < max_slots)) && ((selected++)) ;;
      s)
        if [[ -n "$item_ref" ]]; then
          local item_value
          item_value=$(obj_get "$item_ref" "value")
          set_player_stat "gold" $((gold + item_value))
          print_ui "" "Sold for ${item_value} gold!"
          destroy_item_abs "$item_ref"
          obj_set "player_ref" "$slot_name" ""
          #if ((selected > 1)); then
          #  ((selected--))
          #fi
        else
          print_ui "" "Nothing to sell."
        fi
        ;;
      q | $'\x1b') break ;;
    esac
  done
  draw
}

trade() {
  local npc_ref="$1"
  local selected=0
  local options=("Buy" "Sell")
  if is_empty_inventory "$npc_ref"; then
      local map=$(get_player_stat "map")
      fill_npc_inv "$npc_ref" "$map"
  fi
  while :; do
    clear_frame_buffer
    draw_box 0 0 $((TERM_WIDTH - 1)) $((TERM_HEIGHT - 1))
    v_line $((TERM_WIDTH - 36)) 1 $((TERM_HEIGHT - UI_LOG_MAX - 2))
    h_line 0 $((TERM_HEIGHT - UI_LOG_MAX - 2)) $((TERM_WIDTH - 1))
    print_ui_draw
    plot_inv 2 1 "Trade with NPC:" "\033[1m"
    local base_y=3
    for i in "${!options[@]}"; do
      local display="${options[$i]}"
      local y=$((base_y + i * 2))
      if (( i == selected )); then
        plot_inv $((TERM_WIDTH - 30)) "$y" " $display " "\033[47;30m"
      else
        plot_inv $((TERM_WIDTH - 30)) "$y" " $display "
      fi
    done
    draw
    local key
    key=$(read_key)
    case "$key" in
      $'\x1b[A') ((selected--)); ((selected < 0)) && selected=1 ;; # up
      $'\x1b[B') ((selected++)); ((selected > 1)) && selected=0 ;; # down
      "") # Enter
        case "$selected" in
          0) buy "$npc_ref" ;;
          1) sell "$npc_ref" ;;
        esac
        ;;
      q|Q)
        return ;;
    esac
  done
}

talk() {
  local npc_ref="$1"
  local selected=0
  local options=("Name" "Job" "Trade")
  while :; do
    clear_frame_buffer
    draw_box 0 0 $((TERM_WIDTH - 1)) $((TERM_HEIGHT - 1))
    v_line $((TERM_WIDTH - 36)) 1 $((TERM_HEIGHT - UI_LOG_MAX - 2))
    h_line 0 $((TERM_HEIGHT - UI_LOG_MAX - 2)) $((TERM_WIDTH - 1))
    print_ui_draw
    local npc_name
    npc_name=$(obj_get "$npc_ref" "name")
    plot_inv 2 1 "$npc_name:" "\033[1m"
    local base_y=3
    for i in "${!options[@]}"; do
      local display="${options[$i]}"
      local y=$((base_y + i * 2))
      if (( i == selected )); then
        plot_inv $((TERM_WIDTH - 30)) "$y" " $display " "\033[47;30m"
      else
        plot_inv $((TERM_WIDTH - 30)) "$y" " $display "
      fi
    done
    draw
    local key
    key=$(read_key)
    case "$key" in
      $'\x1b[A') ((selected--)); ((selected < 0)) && selected=2 ;;
      $'\x1b[B') ((selected++)); ((selected > 2)) && selected=0 ;;
      "") # ENTER
        case "$selected" in
          0)
            plot_inv 2 5 "Hello, my name is $npc_name."
            draw
            read_key
            ;;
          1)
            local subtype
            subtype=$(obj_get "$npc_ref" "subtype")
            local location
            location=$(get_player_stat "location")
            case "$subtype" in
              1) plot_inv 2 5 "I am a merchant here in $location." ;;
              2) plot_inv 2 5 "I am the healer of $location." ;;
              *) plot_inv 2 5 "Just a resident of $location." ;;
            esac
            draw
            read_key
            ;;
          2)
            trade "$npc_ref"
            ;;
        esac
        ;;
      q|Q) return ;;
    esac
  done
}


show_stats() {
    clear_frame_buffer
    draw_box 0 0 $((TERM_WIDTH - 1)) $((TERM_HEIGHT - 1))
    local y=2
    local x=4
    plot_inv $x $((y++)) "===== PLAYER STATS =====" "\033[1m"
    y=$((y + 1))
    local stats=(
        level experience next_level_exp hp hp_max mana mana_max
        strength vitality energy dexterity
        defense min_damage max_damage
        fire_resistence cold_resistence poison_resistence lightning_resistence
        block_rate
        fire_damage_min fire_damage_max
        cold_damage_min cold_damage_max
        poison_damage poison_damage_time
        lightning_damage_min lightning_damage_max
    )
    local equip_slots=(weapon shield helmet armor amulet ring)
    for stat in "${stats[@]}"; do
        local base_val="${player_ref[$stat]:-0}"
        local total_val=$base_val
        for slot in "${equip_slots[@]}"; do
            local eq_ref="${player_ref[$slot]}"
            if [[ -n "$eq_ref" ]]; then
                local val
                val=$(obj_get "$eq_ref" "$stat")
                [[ -z "$val" ]] && val=0
                (( total_val += val ))
            fi
        done
        if [[ "$stat" =~ _min$ ]]; then
            local base="${stat%_min}"
            local min_val=$total_val
            local max_key="${base}_max"
            local base_max="${player_ref[$max_key]:-0}"
            local total_max=$base_max
            for slot in "${equip_slots[@]}"; do
                local eq_ref="${player_ref[$slot]}"
                if [[ -n "$eq_ref" ]]; then
                    local val2
                    val2=$(obj_get "$eq_ref" "$max_key")
                    [[ -z "$val2" ]] && val2=0
                    (( total_max += val2 ))
                fi
            done
            plot_inv $x $((y++)) "$(printf '%-22s %s - %s' "$base" "$min_val" "$total_max")"
        elif [[ ! "$stat" =~ _max$ ]]; then
            plot_inv $x $((y++)) "$(printf '%-22s %s' "$stat" "$total_val")"
        fi
    done
    y=$((y + 2))
    plot_inv $x $y "Press [q] to return." "\033[2m"
    draw
    while true; do
        key=$(read_key)
        case "$key" in
            q | $'\x1b') break ;;
        esac
    done
    draw
}

declare -a lastx=(0 0 0 0)
declare -a lasty=(0 0 0 0)

random_encounter() {
  local map_type
  map_type=$(get_player_stat "map_type")
  if [[ "$map_type" -ne 4 ]]; then
    return 0
  fi
  local rnd=$((RANDOM % 100))
  if ((rnd < 5)); then
    create_swarm
  fi
  rnd=$((RANDOM % 100))
  if ((rnd < 2)); then
    create_random_portal
  fi
}

move_up() {
  local x y
  x=$PLAYER_X
  y=$PLAYER_Y
  local target_y=$((y - 1))
  if coords_out_of_bounds "$x" "$target_y"; then
    load_overworld
    local last_x last_y
    last_x=$(get_player_stat "lastx")
    last_y=$(get_player_stat "lasty")
    set_player_stat "x" "$last_x"
    set_player_stat "y" "$last_y"
    set_player_stat "location" "overwolrd"
    print_ui "" "You entered overworld"
    return
  fi
 local npc_ref
npc_ref=$(npc_on_xy "$x" "$target_y")
if [[ -n "$npc_ref" ]]; then
    local subtype="${NPC[subtype]:-}"
    declare -n NPC="$npc_ref"
    if [[ "${NPC[subtype]}" == "0" ]]; then
        attack "player_ref" "$npc_ref"
    else
        talk "$npc_ref"
    fi
    return
fi
  try_move_npc "player_ref" "$x" "$target_y"
  local dy=$((target_y - y))
  lasty=("$dy" "${lasty[@]:0:3}")
  lastx=(0 "${lastx[@]:0:3}")
  random_encounter
}

move_down() {
  local x y
  x=$PLAYER_X
  y=$PLAYER_Y
  local target_y=$((y + 1))
  if coords_out_of_bounds "$x" "$target_y"; then
    load_overworld
    local last_x last_y
    last_x=$(get_player_stat "lastx")
    last_y=$(get_player_stat "lasty")
    set_player_stat "x" "$last_x"
    set_player_stat "y" "$last_y"
    print_ui "" "You entered overworld"
    set_player_stat "location" "overwolrd"
    return
  fi
  local npc_ref
npc_ref=$(npc_on_xy "$x" "$target_y")
if [[ -n "$npc_ref" ]]; then
    local subtype="${NPC[subtype]:-}"
    declare -n NPC="$npc_ref"
    if [[ "${NPC[subtype]}" == "0" ]]; then
        attack "player_ref" "$npc_ref"
    else
        talk "$npc_ref"
    fi
    return
fi
  try_move_npc "player_ref" "$x" "$target_y"
  local dy=$((target_y - y))
  lasty=("$dy" "${lasty[@]:0:3}")
  lastx=(0 "${lastx[@]:0:3}")
  random_encounter
}

move_left() {
  local x y
  x=$PLAYER_X
  y=$PLAYER_Y
  local target_x=$((x - 1))
  if coords_out_of_bounds "$target_x" "$y"; then
    load_overworld
    local last_x last_y
    last_x=$(get_player_stat "lastx")
    last_y=$(get_player_stat "lasty")
    set_player_stat "x" "$last_x"
    set_player_stat "y" "$last_y"
    print_ui "" "You entered overworld"
    set_player_stat "location" "overwolrd"
    return
  fi
local npc_ref
npc_ref=$(npc_on_xy "$target_x" "$y")
if [[ -n "$npc_ref" ]]; then
    local subtype="${NPC[subtype]:-}"
    declare -n NPC="$npc_ref"
    if [[ "${NPC[subtype]}" == "0" ]]; then
        attack "player_ref" "$npc_ref"
    else
        talk "$npc_ref"
    fi
    return
fi
  try_move_npc "player_ref" "$target_x" "$y"
  local dx=$((target_x - x))
  lastx=("$dx" "${lastx[@]:0:3}")
  lasty=(0 "${lasty[@]:0:3}")

  random_encounter
}

move_right() {
  local x y
  x=$PLAYER_X
  y=$PLAYER_Y
  local target_x=$((x + 1))
  if coords_out_of_bounds "$target_x" "$y"; then
    load_overworld
    local last_x last_y
    last_x=$(get_player_stat "lastx")
    last_y=$(get_player_stat "lasty")
    set_player_stat "x" "$last_x"
    set_player_stat "y" "$last_y"
    print_ui "" "You entered overworld"
    set_player_stat "location" "overwolrd"
    return
  fi
  local npc_ref
npc_ref=$(npc_on_xy "$target_x" "$y")
if [[ -n "$npc_ref" ]]; then
    local subtype="${NPC[subtype]:-}"
    declare -n NPC="$npc_ref"

    if [[ "${NPC[subtype]}" == "0" ]]; then
        attack "player_ref" "$npc_ref"
    else
        talk "$npc_ref"
    fi
    return
fi
  try_move_npc "player_ref" "$target_x" "$y"
  local dx=$((target_x - x)) # bude +1
  lastx=("$dx" "${lastx[@]:0:3}")
  random_encounter
}

get_player_deltax() {
  local sum=0
  for delta in "${lastx[@]}"; do
    ((sum += delta))
  done
  echo "$sum"
}

get_player_deltay() {
  local sum=0
  for delta in "${lasty[@]}"; do
    ((sum += delta))
  done
  echo "$sum"
}

show_main_menu() {
  :
}

show_intro_menu() {
  local options=("Load Game" "New Game" "Exit")
  local selected=0
  local key=""
  local normal="\e[0m"
  local highlight="\e[47;30m" # šedé pozadí + černý text
  echo -ne "\e[?25l"
  trap 'echo -ne "\e[?25h"' EXIT
  move_cursor() { # $1 = row, $2 = col
    echo -ne "\e[${1};${2}H"
  }

  draw_menu() {
    echo -ne "\e[2J" # clear screen
    local logo=(
      "██████   █████  ████████ ██   ██"
      "██   ██ ██   ██    ██    ██   ██"
      "██████  ███████    ██    ███████"
      "██      ██   ██    ██    ██   ██"
      "██      ██   ██    ██    ██   ██"
    )
    local logo_start_y=$((TERM_HEIGHT / 2 - 8))
    for i in "${!logo[@]}"; do
      local line="${logo[$i]}"
      local text_x=$((TERM_WIDTH / 2 - ${#line} / 2))
      move_cursor $((logo_start_y + i)) $text_x
      echo -ne "\e[96m${line}\e[0m"
    done
    local mid_y=$((TERM_HEIGHT / 2 + 2))
    local mid_x=$((TERM_WIDTH / 2))
    for i in "${!options[@]}"; do
      local text="${options[$i]}"
      local text_x=$((mid_x - ${#text} / 2))
      move_cursor $((mid_y + i)) $text_x
      if [[ $i -eq $selected ]]; then
        echo -ne "${highlight}${text}${normal}"
      else
        echo -ne "${normal}${text}${normal}"
      fi
    done
    move_cursor $((TERM_HEIGHT)) 1
  }
  while true; do
    draw_menu
    read -rsn1 key
    case "$key" in
      $'\x1b')
        read -rsn2 key
        case "$key" in
          "[A") ((selected--)) ;;
          "[B") ((selected++)) ;;
        esac
        ;;
      "")
        echo -ne "\e[2J"
        case $selected in
  0)
    if load_game; then
      return
    fi
    ;;
  1) new_game; return ;;
  2) exit 0 ;;
esac
        ;;
    esac
    ((selected < 0)) && selected=$((${#options[@]} - 1))
    ((selected >= ${#options[@]})) && selected=0
  done
}

show_level_up() {
  local points
  points=1
  local attrs=("strength" "vitality" "energy" "dexterity")
  local descs=(
    "Each point increases min/max damage by your Strength each level."
    "Each point adds to HP gained per level."
    "Each point adds to Mana gained per level."
    "Each point increases Defense by Dexterity and 1 Block Rate per 4 Dexterity."
  )
  declare -A values
  for attr in "${attrs[@]}"; do
    values[$attr]=$(get_player_stat "$attr")
  done
  local selected=0
  local key=""
  while true; do
    clear_frame_buffer
    draw_box 0 0 $((TERM_WIDTH - 1)) $((TERM_HEIGHT - 1))
    local divider_x=$((TERM_WIDTH / 2))
    v_line "$divider_x" 1 $((TERM_HEIGHT - 2))
    plot_inv 3 1 "LEVEL UP!" "\033[1m"
    plot_inv 3 2 "Distribute your stat points" "\033[0m"
    plot_inv 3 3 "(${points} remaining)" "\033[0m"
    plot_inv 3 5 "Use ↑/↓ to move, 'a' to add points." "\033[2m"
    local y=7
    for i in "${!attrs[@]}"; do
      local attr="${attrs[$i]}"
      local color="\033[0m"
      if ((i == selected)); then
        color="\033[1;30;47m"
      fi
      plot_inv 5 $((y + i)) "$(printf '%-12s %3d' "${attr^}:" "${values[$attr]}")" "$color"
    done
    local desc_y=3
    local right_x=$((divider_x + 3))
    plot_inv "$right_x" "$desc_y" "Description:" "\033[1m"
    desc_y=$((desc_y + 2))
    local desc="${descs[$selected]}"
    local line=""
    local word
    local line_width=35
    for word in $desc; do
      if ((${#line} + ${#word} + 1 > line_width)); then
        plot_inv "$right_x" "$desc_y" "$line"
        line="$word"
        ((desc_y++))
      else
        if [[ -z "$line" ]]; then
          line="$word"
        else
          line="$line $word"
        fi
      fi
    done
    [[ -n "$line" ]] && plot_inv "$right_x" "$desc_y" "$line"
    draw
    if ((points == 0)); then
      sleep 0.5
      break
    fi
    key=$(read_key)
    case "$key" in
      $'\x1b[A') ((selected > 0)) && ((selected--)) ;;                # šipka nahoru
      $'\x1b[B') ((selected < ${#attrs[@]} - 1)) && ((selected++)) ;; # šipka dolů
      a | A)
        if ((points > 0)); then
          local attr="${attrs[$selected]}"
          ((values[$attr]++))
          ((points--))
        fi
        ;;
    esac
  done
  for attr in "${attrs[@]}"; do
    set_player_stat "$attr" "${values[$attr]}"
  done
  clear_frame_buffer
  draw_box 0 0 $((TERM_WIDTH - 1)) $((TERM_HEIGHT - 1))
  plot_inv 3 3 "All points distributed! Level up complete." "\033[1m"
  draw
  sleep 1.5
}

show_help() {
  stty "$STTY_SAVE"
  local help_lines=(
    "GAME HELP"
    ""
    "Arrow Up    - Move Up"
    "Arrow Down  - Move Down"
    "Arrow Right - Move Right"
    "Arrow Left  - Move Left"
    "            - Arrows also used for attack and talk"
    "q           - Save Game and Exit"
    "i           - Show Inventory"
    "              u - Use Item in Inventory"
    "              e - Equip Item in Inventory"
    "              q - Exit Inventory"
    "s           - Show Stats"
    "              q - Exit Stats"
    "g           - Pick up item (get)"
    "1-4         - Use potion from slot 1-4"
    "r           - Rest (requires food, no monsters nearby)"
    "e           - Enter a portal"
    "h           - Show this Help"
    ""
    "Press ENTER to continue..."
  )
  printf "\033[H\033[2J"
  local line
  for line in "${help_lines[@]}"; do
    echo "$line"
  done
  read
  stty -echo -icanon time 0 min 0
  draw
}

select_target() {
  local spell_ref="$1"
  local key=""
  local cur_x=$(( VIEWPORT_WIDTH / 2 ))
  local cur_y=$(( VIEWPORT_HEIGHT / 2 ))
  declare -A TEMP_BUFFER=()
  for coord in "${!FRAME_BUFFER[@]}"; do
    TEMP_BUFFER["$coord"]="${FRAME_BUFFER[$coord]}"
  done
  local spell_name
  spell_name=$(obj_get "$spell_ref" "name")
  if [[ "$spell_name" == "Heal" ]]; then
          apply_spell "$spell_ref" "player_ref"
          return 0
  fi

  while true; do
    for coord in "${!TEMP_BUFFER[@]}"; do
      FRAME_BUFFER["$coord"]="${TEMP_BUFFER[$coord]}"
    done
    (( cur_x < 0 )) && cur_x=0
    (( cur_y < 0 )) && cur_y=0
    (( cur_x >= VIEWPORT_WIDTH )) && cur_x=$(( VIEWPORT_WIDTH - 1 ))
    (( cur_y >= VIEWPORT_HEIGHT )) && cur_y=$(( VIEWPORT_HEIGHT - 1 ))
    draw_interface
    local tile="${FRAME_BUFFER["$((VIEWPORT_X + cur_x - 1)),$((VIEWPORT_Y + cur_y - 1))"]}"
    FRAME_BUFFER["$((VIEWPORT_X + cur_x - 1)),$((VIEWPORT_Y + cur_y -1))"]="\033[47;30m${tile:- }\033[0m"
    draw
    key=$(read_key)
    case "$key" in
      $'\x1b[A') ((cur_y--)) ;;  # nahoru
      $'\x1b[B') ((cur_y++)) ;;  # dolů
      $'\x1b[D') ((cur_x--)) ;;  # vlevo
      $'\x1b[C') ((cur_x++)) ;;  # vpravo
      "") # Enter
        local map_x=$(( PLAYER_X - VIEWPORT_WIDTH / 2 + cur_x ))
        local map_y=$(( PLAYER_Y - VIEWPORT_HEIGHT / 2 + cur_y ))
local npc_ref
npc_ref=$(npc_on_xy "$map_x" "$map_y")
if ! scan_line "$PLAYER_X" "$PLAYER_Y" "$map_x" "$map_y"; then
  print_ui "" "Your spell cannot reach the target!"
  return 1
fi
local dx=$(( PLAYER_X - map_x ))
local dy=$(( PLAYER_Y - map_y ))
(( dx < 0 )) && dx=$(( -dx ))
(( dy < 0 )) && dy=$(( -dy ))
if (( dx > 10 || dy > 10 )); then
  print_ui "" "The target is too far away."
  return 1
fi
if [[ -n "$npc_ref" ]]; then
  apply_spell "$spell_ref" "$npc_ref"
  return 0
else
  print_ui "" "There is no target here."
fi
        ;;
      q | $'\x1b')  # ukončit výběr
        return 0
        ;;
    esac
  done
}

cast() {
    clear_frame_buffer
    draw_box 0 0 $((TERM_WIDTH - 1)) $((TERM_HEIGHT - 1))
    v_line $((TERM_WIDTH - 36)) 1 $((TERM_HEIGHT - UI_LOG_MAX - 2))
    h_line 0 $((TERM_HEIGHT - UI_LOG_MAX - 2)) $((TERM_WIDTH - 1))
    print_ui_draw
    if ((${#SPELL_REGISTRY[@]} == 0)); then
        local msg="You do not know any spells yet."
        local x=$(( (TERM_WIDTH - ${#msg}) / 2 ))
        local y=$(( TERM_HEIGHT / 2 ))
        clear_frame_buffer
        plot_inv "$x" "$y" "$msg" "\033[1;37m"
        draw
        read -rsn1
        return 0
    fi
    local selection=0
    local key spell_ref spell_name spell_y i
    while true; do
        clear_frame_buffer
        draw_box 0 0 $((TERM_WIDTH - 1)) $((TERM_HEIGHT - 1))
        v_line $((TERM_WIDTH - 36)) 1 $((TERM_HEIGHT - UI_LOG_MAX - 2))
        h_line 0 $((TERM_HEIGHT - UI_LOG_MAX - 2)) $((TERM_WIDTH - 1))
        print_ui_draw
        plot_inv 2 1 "SPELLBOOK:" "\033[1;33m"
        i=0
        for spell_ref in "${SPELL_REGISTRY[@]}"; do
            spell_name=$(obj_get "$spell_ref" "name")
            spell_y=$((3 + i))
            if ((i == selection)); then
                plot_inv 2 "$spell_y" "▶ $spell_name" "\033[47;30m"
            else
                plot_inv 2 "$spell_y" "  $spell_name" "\033[1;37m"
            fi
            ((i++))
        done
        spell_ref="${SPELL_REGISTRY[$selection]}"
        local y_offset=2
        local x_right=$((TERM_WIDTH - 34))
        plot_inv "$x_right" "$y_offset" "Spell Info:" "\033[1;36m"
        ((y_offset+=2))
        for prop in fire_damage_min fire_damage_max \
                    cold_damage_min cold_damage_max \
                    lightning_damage_min lightning_damage_max \
                    hp_min hp_max; do
            local val
            val=$(obj_get "$spell_ref" "$prop")
            [[ -n "$val" && "$val" != "0" ]] || continue
            local prop_name=""
            case "$prop" in
                fire_damage_min) prop_name="Fire Dmg Min";;
                fire_damage_max) prop_name="Fire Dmg Max";;
                cold_damage_min) prop_name="Cold Dmg Min";;
                cold_damage_max) prop_name="Cold Dmg Max";;
                lightning_damage_min) prop_name="Lightning Dmg Min";;
                lightning_damage_max) prop_name="Lightning Dmg Max";;
                hp_min) prop_name="Heal Min";;
                hp_max) prop_name="Heal Max";;
            esac
            plot_inv "$x_right" "$y_offset" "$prop_name: $val" "\033[1;37m"
            ((y_offset++))
        done
        draw
        read -rsn1 key
        case "$key" in
            $'\x1b') # escape sekvence
                read -rsn2 key
                case "$key" in
                    "[A") # up
                        ((selection--))
                        ((selection < 0)) && selection=$(( ${#SPELL_REGISTRY[@]} - 1 ))
                        ;;
                    "[B") # down
                        ((selection++))
                        ((selection >= ${#SPELL_REGISTRY[@]})) && selection=0
                        ;;
                esac
                ;;
            "") # Enter
                spell_ref="${SPELL_REGISTRY[$selection]}"
                select_target "$spell_ref"
                return 0
                ;;
            q|Q) # možnost zrušit výběr
                return 0
                ;;
        esac
    done
}
