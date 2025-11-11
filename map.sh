[[ -n "${_MAP_SH_INCLUDED:-}" ]] && return
_MAP_SH_INCLUDED=1
source ui.sh
source object.sh
source player.sh
source npc.sh
source item.sh

if [[ -z "${PORTAL_REGISTRY_LOADED:-}" ]]; then
  declare -ag PORTAL_REGISTRY=()
  PORTAL_REGISTRY_LOADED=1
fi

if [[ -z "${MAP_REGISTRY_LOADED:-}" ]]; then
  declare -ag MAP_REGISTRY=()
  MAP_REGISTRY_LOADED=1
fi

declare -A TILE_RENDER=(
  ["a"]="\e[32m."  # tráva
  ["b"]="\e[33m."  # cesta
  ["W"]="\e[37m#"  # zeď
  ["T"]="\e[32m♤"  # strom
  ["t"]="\e[32m♧"  # strom 2
  ["S"]="\e[93m\$" # obchodník
  ["H"]="\e[93mH"  # hospoda
  ["C"]="\e[97m+"  # kaple
  ["="]="\e[96m="  # portál
  ["c"]="\e[34m."  # voda
  ["d"]="\e[39m^"  # hora (šedá)
  ["e"]="\e[39m."  # dlažba
)

declare -A TILE_WALKABLE=(
  ["a"]=1
  ["b"]=1
  ["="]=1
  ["S"]=1
  ["H"]=1
  ["C"]=1
  ["W"]=0
  ["T"]=1
  ["t"]=1
  ["c"]=1
  ["d"]=0
  ["e"]=1
)

load_map_registry() {
    local file="save/maps/_registry.txt"
    MAP_REGISTRY=()
    [[ ! -f "$file" ]] && return 0
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        [[ "$line" =~ ^# ]] && continue
        MAP_REGISTRY+=("$line")
    done < "$file"
    return 0
}


save_map_registry() {
    local file="save/maps/_registry.txt"
    mkdir -p "save/maps"
    {
        echo "# Registry of all maps"
        for map in "${MAP_REGISTRY[@]}"; do
            echo "$map"
        done
    } > "$file"
}

get_map_name() {
    local used_ids=()
    local map
    for map in "${MAP_REGISTRY[@]}"; do
        if [[ "$map" =~ ^map([0-9]+)$ ]]; then
            used_ids+=("${BASH_REMATCH[1]}")
        fi
    done
    local id=1
    local used
    while :; do
        local found=0
        for used in "${used_ids[@]}"; do
            if [[ 10#$used -eq "$id" ]]; then
                found=1
                break
            fi
        done
        [[ $found -eq 0 ]] && break
        ((id++))
    done
    printf -v assigned_map_name "map%04d" "$id"
    MAP_REGISTRY+=("$assigned_map_name")
    return 0
}

declare -i MAP_WIDTH
declare -i MAP_HEIGHT

tile_is_passable() {
  [[ "${TILE_WALKABLE[$1]}" -eq 1 ]]
}

coords_out_of_bounds() {
  local x="$1"
  local y="$2"
  ((x < 0 || x >= MAP_WIDTH || y < 0 || y >= MAP_HEIGHT)) && return 0
  return 1
}

map_tile_render() {
  local tile="$1"
  if [[ -n "${TILE_RENDER[$tile]}" ]]; then
    echo -e "${TILE_RENDER[$tile]}"
  else
    echo -e ".\e[32m"
  fi
}

get_map_tile_xy() {
  local x=$1
  local y=$2
  ((y < 0 || y >= MAP_HEIGHT)) && echo " " && return
  ((x < 0 || x >= MAP_WIDTH)) && echo " " && return
  local line="${map_data[$y]}"
  echo "${line:$x:1}"
}

is_space_free() {
    local center_x=$1
    local center_y=$2
    for dy in {-2..2}; do
        for dx in {-2..2}; do
            local x=$((center_x + dx))
            local y=$((center_y + dy))
            local tile
            tile=$(get_map_tile_xy "$x" "$y")
            [[ -z "$tile" || "$tile" == " " ]] && return 1
            if ! tile_is_passable "$tile"; then
                return 1
            fi
        done
    done
    return 0
}

try_move_npc() {
  local npc_ref=$1
  local nx=$2
  local ny=$3
  declare -n NPC="$npc_ref"
  local tile
  tile=$(get_map_tile_xy "$nx" "$ny")
  if tile_is_passable "$tile"; then
    NPC[x]="$nx"
    NPC[y]="$ny"
    return 0
  else
    if [[ "$npc_ref" == "player_ref" ]]; then
      print_ui "" "You can't go that way!"
    fi
  fi
  return 1
}

register_portal() {
  local portal_ref=$1
  local portal
  for portal in "${pPORTAL_REGISTRY[@]}"; do
    if [[ "$portal" == "$portal_ref" ]]; then
      return 1
    fi
  done
  PORTAL_REGISTRY+=("$portal_ref")
}

unregister_portal() {
  local portal_ref=$1
  local new_registry=()
  local portal
  for portal in "${PORTAL_REGISTRY[@]}"; do
    if [[ "$portal" != "$portal_ref" ]]; then
      new_registry+=("$portal")
    fi
  done
  PORTAL_REGISTRY=("${new_registry[@]}")
}

get_portal_obj_ref() {
  local used_ids=()
  local portal
  for portal in "${PORTAL_REGISTRY[@]}"; do
    if [[ "$portal" =~ ^portal([0-9]+)$ ]]; then
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
  local portal_ref
  printf -v portal_ref "portal%03d" "$id"
  unset "$portal_ref"
  declare -gA "$portal_ref=()"
  assigned_portal_ref="$portal_ref"
}

iterate_over_portals() {
  local func_name=$1
  shift
  local portal_ref
  for portal_ref in "${PORTAL_REGISTRY[@]}"; do
    "$func_name" "$portal_ref" "$@"
  done
}

iterate_over_portals_par() {
  local func_name=$1
  shift
  local portal_ref
  for portal_ref in "${PORTAL_REGISTRY[@]}"; do
    "$func_name" "$portal_ref" "$@" &
  done
  wait
}

save_map() {
  local name="$1"
  local dir="save/maps"
  local file="$dir/$name"
  mkdir -p "$dir"
  >"$file"
  local y
  for y in "${!map_data[@]}"; do
    printf "%s\n" "${map_data[$y]}" >>"$file"
  done
}

map_load() {
  local file="$1"
  if [[ ! -f "save/maps/$file" ]]; then
    return 1
  fi
  map_data=()
  MAP_WIDTH=0
  MAP_HEIGHT=0
  local line len i=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    map_data["$i"]="$line"
    len=${#line}
    ((len > MAP_WIDTH)) && MAP_WIDTH=$len
    ((i++))
  done <"save/maps/$file"
  MAP_HEIGHT=$i
}

map_render_to_buffer() {
    local player_x player_y
    player_x=$(get_player_stat "x")
    player_y=$(get_player_stat "y")
    local start_x=$((player_x - VIEWPORT_WIDTH / 2))
    local start_y=$((player_y - VIEWPORT_HEIGHT / 2))
    local y x screen_y screen_x
    screen_y=0
    for ((y = start_y; y < start_y + VIEWPORT_HEIGHT + 1; y++)); do
        screen_x=0
        local row=""
        if (( y < 0 || y >= MAP_HEIGHT )); then
            row=$(printf ' %.0s' $(seq 1 $MAP_WIDTH))
        else
            row="${map_data[$y]}"
        fi

        for ((x = start_x; x < start_x + VIEWPORT_WIDTH; x++)); do
            if (( x < 0 || x >= MAP_WIDTH || y < 0 || y >= MAP_HEIGHT )); then
                FRAME_BUFFER["$screen_x,$screen_y"]=" "
            else
                local tile_char="${row:x:1}"
                FRAME_BUFFER["$screen_x,$screen_y"]="${TILE_RENDER[$tile_char]:-a}"
            fi
            ((screen_x++))
        done
        ((screen_y++))
    done
}

save_portal() {
  local portal_ref=$1
  local map=$(get_player_stat "map")
  obj_store "$portal_ref" "save/maps/$map.d/portals" "$portal_ref"
}

save_portals() {
  iterate_over_portals_par save_portal
}

destroy_portal() {
  local poral_ref=$1
  unregister_portal "$portal_ref"
  destroy_object "$portal_ref"
}

delete_all_portals() {
  iterate_over_portals "destroy_portal"
}

load_portals() {
  local map=$(get_player_stat "map")
  local dir="save/maps/$map.d/portals"
  [[ ! -d "$dir" ]] && return
  local file
  shopt -s nullglob
  for file in "$dir"/*; do
    local base
    base=$(basename "$file")
    local portal_ref="$base"
    declare -g -A "$portal_ref"
    obj_load "$portal_ref" "$dir" "$base"
    register_portal "$portal_ref"
  done
  shopt -u nullglob
  rm -rf "$dir"/*
}

load_npcs_from_map() {
  load_npcs
}

load_items_from_map() {
  load_items
}

load_portals_from_map() {
  load_portals
}

unload_items() {
  save_items
  delete_all_items
}

unload_npcs() {
  save_npcs
  delete_all_npcs
}

unload_portals() {
  save_portals
  delete_all_portals
}

change_map() {
  local new_map=$1
  local new_map_type=$2
  unload_items
  unload_npcs
  unload_portals
  set_player_stat "map" "$new_map"
  set_player_stat "map_type" "$new_map_type"
  map_load "$new_map"
  load_npcs_from_map
  load_items_from_map
  load_portals_from_map
}

portal_on_xy_helper() {
  local portal_ref=$1
  local x=$2
  local y=$3
  local portalx portaly
  portalx=$(obj_get "$portal_ref" "x")
  portaly=$(obj_get "$portal_ref" "y")
  if [[ "$x" == "$portalx" && "$y" == "$portaly" ]]; then
    echo "$portal_ref"
  fi
}

portal_on_xy() {
    local x=$1
    local y=$2
    iterate_over_portals_par portal_on_xy_helper "$x" "$y"
}

create_back_portal() {
  local portal_ref=$1
  local x=$2
  local y=$3
  local level
  level=$(obj_get "$portal_ref" "level")
  local back_portal="back_portal_ref_$level"
  unset "$back_portal"
  declare -gA "$back_portal"
  create_blank_object "$back_portal"
  obj_set "$back_portal" "x" "$x"
  obj_set "$back_portal" "y" "$y"
  local prev_map=$(obj_get "$portal_ref" "map")
  obj_set "$back_portal" "target_map" "$prev_map"
  local prev_location=$(obj_get "$portal_ref" "location")
  obj_set "$back_portal" "name" "$prev_location"
  obj_set "$back_portal" "target_x" $(obj_get "$portal_ref" "x")
  obj_set "$back_portal" "target_y" $(obj_get "$portal_ref" "y")
  obj_set "$back_portal" "level" "$level"
  local level
  level=$(obj_get "$portal_ref" "level")
  if ((level == 1)); then
    obj_set "$back_portal" "icon" "E"
    local subtype=$(obj_get "$portal_ref" "map_type")
    obj_set "$back_portal" "subtype" "$subtype"
  elif ((level >= 2 && level <= 9)); then
    obj_set "$back_portal" "icon" $(( level - 1 ))
    obj_set "$back_portal" "subtype" 0
  else
    obj_set "$back_portal" "icon" "?"
    obj_set "$back_portal" "subtype" 0
  fi
  local current_map=$(obj_get "$portal_ref" "target_map")
   obj_store "$back_portal" "save/maps/$current_map.d/portals" "$back_portal"
}

create_forward_portal() {
  local portal_ref=$1
  local x=$2
  local y=$3
  local level name
  level=$(obj_get "$portal_ref" "level")
  local forward_portal="forward_portal_ref_$level"
  unset "$forward_portal"
  declare -gA "$forward_portal"
  create_blank_object "$forward_portal"
  ((level++))
  name=$(obj_get "$portal_ref" "name")
  obj_set "$forward_portal" "x" "$x"
  obj_set "$forward_portal" "y" "$y"
  obj_set "$forward_portal" "name" "$name"
  obj_set "$forward_portal" "location" "$name"
  obj_set "$forward_portal" "level" "$level"
  obj_set "$forward_portal" "subtype" 0
  get_map_name
  local map_name="$assigned_map_name"
  obj_set "$forward_portal" "target_map" "$map_name"
  local cur_location
  cur_location=$(obj_get "$portal_ref" "name")
  obj_set "$forward_portal" "location" "$cur_location"
  if (( level >= 1 && level <= 9 )); then
      obj_set "$forward_portal" "icon" "$level"
  else
      obj_set "$forward_portal" "icon" "?"
  fi
  local current_map
  current_map=$(obj_get "$portal_ref" "target_map")
  obj_set "$forward_portal" "map" "$current_map"
  obj_store "$forward_portal" "save/maps/$current_map.d/portals" "$forward_portal"
}


generate_dungeon() {
  local portal_ref=$1
  if [[ "$(obj_get "$portal_ref" "level")" -eq 0 ]]; then
    obj_set "$portal" "level" 1
  fi
  local WIDTH=100
  local HEIGHT=100
  local ROOM_COUNT=16
  local MIN_ROOM_SIZE=5
  local MAX_ROOM_SIZE=15
  declare -a used_ids_items=()
  map_data=()
  for ((y = 0; y < HEIGHT; y++)); do
    map_data["$y"]=$(printf 'W%.0s' $(seq 1 $WIDTH))
  done
  local target_map
  target_map=$(obj_get "$portal_ref" "target_map")
  local rooms=()
  local i=0
  local forward_spawned=0
  while ((i < ROOM_COUNT)); do
    local rw=$((MIN_ROOM_SIZE + RANDOM % (MAX_ROOM_SIZE - MIN_ROOM_SIZE + 1)))
    local rh=$((MIN_ROOM_SIZE + RANDOM % (MAX_ROOM_SIZE - MIN_ROOM_SIZE + 1)))
    local rx=$((RANDOM % (WIDTH - rw - 1) + 1))
    local ry=$((RANDOM % (HEIGHT - rh - 1) + 1))
    local overlap=0
    for room in "${rooms[@]}"; do
      local r=($room)
      if ((rx < r[0] + r[2] && rx + rw > r[0] && ry < r[1] + r[3] && ry + rh > r[1])); then
        overlap=1
        break
      fi
    done
    ((overlap)) && continue
    for ((y2 = ry; y2 < ry + rh; y2++)); do
      local row="${map_data[$y2]}"
      for ((x2 = rx; x2 < rx + rw; x2++)); do
        row="${row:0:$x2}b${row:$((x2 + 1))}" # 'b' = podlaha
      done
      map_data["$y2"]="$row"
    done
    rooms+=("$rx $ry $rw $rh")
    ((i++))
    if ((i > 1)); then
      local count=$((2 + RANDOM % 2))
      local s
      for ((s = 0; s < count; s++)); do
        local mx my tile
          mx=$((rx + RANDOM % rw))
          my=$((ry + RANDOM % rh))
        local id=1
        local used_ids
        while :; do
          local found=0
          local used
          for used in "${used_ids[@]}"; do
            [[ "$used" -eq "$id" ]] && found=1 && break
          done
          ((found == 0)) && break
          ((id++))
        done
        used_ids+=("$id")
        local mref
        printf -v mref "%smonster%03d" "$target_map" "$id"
        unset "$mref"
        declare -gA "$mref"
        create_random_monster_no_reg "$mref"
        obj_set "$mref" "x" "$mx"
        obj_set "$mref" "y" "$my"
        obj_store "$mref" "save/maps/$target_map.d/npcs" "$mref"
      done
    fi
if ((i > 1)) && (( RANDOM % 100 < 40 )); then
    local ix iy
    ix=$((rx + RANDOM % rw))
    iy=$((ry + RANDOM % rh))
    local id=1
    local iref
    while :; do
        printf -v iref "%sloot%03d" "$target_map" "$id"
        local exists=0
        for reg in "${ITEM_REGISTRY[@]}"; do
            [[ "$reg" == "$iref" ]] && exists=1 && break
        done
        for used in "${used_ids_items[@]}"; do
            [[ "$used" == "$iref" ]] && exists=1 && break
        done
        ((exists == 0)) && break
        ((id++))
    done
    unset "$iref"
    declare -gA "$iref"
    local player_level
    player_level=$(obj_get "player_ref" "level")
    create_random_magic_item_no_reg "$iref" "$player_level"
    obj_set "$iref" "x" "$ix"
    obj_set "$iref" "y" "$iy"
    obj_store "$iref" "save/maps/$target_map.d/items" "$iref"
    used_ids_items+=("$iref")
fi
    local lvl
    lvl=$(obj_get "$portal_ref" "level")
    if (( i > 1 )) && (( forward_spawned == 0 )) && (( lvl < 9 )) && (( RANDOM % 100 < 50 )); then
      local cx=$((rx + rw / 2))
      local cy=$((ry + rh / 2))
      create_forward_portal "$portal_ref" "$cx" "$cy"
      forward_spawned=1
    fi
  done
  for ((i = 1; i < ${#rooms[@]}; i++)); do
    local prev=(${rooms[$((i - 1))]})
    local cur=(${rooms[$i]})
    local x1=$((prev[0] + prev[2] / 2))
    local y1=$((prev[1] + prev[3] / 2))
    local x2=$((cur[0] + cur[2] / 2))
    local y2=$((cur[1] + cur[3] / 2))
    local y=$y1
    local x_start=$((x1 < x2 ? x1 : x2))
    local x_end=$((x1 > x2 ? x1 : x2))
    for ((x = x_start; x <= x_end; x++)); do
      local row="${map_data[$y]}"
      row="${row:0:$x}b${row:$((x + 1))}"
      map_data["$y"]="$row"
    done
    local x=$x2
    local y_start=$((y1 < y2 ? y1 : y2))
    local y_end=$((y1 > y2 ? y1 : y2))
    for ((y = y_start; y <= y_end; y++)); do
      local row="${map_data[$y]}"
      row="${row:0:$x}bb${row:$((x + 2))}"
      map_data["$y"]="$row"
    done
  done
  local first_room=(${rooms[0]})
  local target_x_g target_y_g
  target_x_g=$((first_room[0] + first_room[2] / 2))
  target_y_g=$((first_room[1] + first_room[3] / 2))
  obj_set "$portal_ref" "target_x" "$target_x_g"
  obj_set "$portal_ref" "target_y" "$target_y_g"
  create_back_portal "$portal_ref" "$target_x_g" "$target_y_g"
  MAP_WIDTH=$WIDTH
  MAP_HEIGHT=$HEIGHT
  save_map "$target_map"
}

create_underground_portal() {
  local portal_ref=$1
  local x=$2
  local y=$3
  local underground_portal="underground_portal_ref"
  unset "$undeground_portal"
  declare -gA "$underground_portal"
  create_blank_object "$underground_portal"
  obj_set "$underground_portal" "x" "$x"
  obj_set "$underground_portal" "y" "$y"
  local name=$(obj_get "$portal_ref" "name")
  obj_set "$underground_portal" "location" "$name"
  obj_set "$underground_portal" "name" "Underground of $name"
  obj_set "$underground_portal" "subtype" 0
  obj_set "$underground_portal" "icon" "U"
  obj_set "$underground_portal" "map_type" 1
  get_map_name
  local map_name="$assigned_map_name"
  obj_set "$underground_portal" "target_map" "$map_name"
  local current_map=$(obj_get "$portal_ref" "target_map")
  obj_set "$underground_portal" "map" "$current_map"
  obj_store "$underground_portal" "save/maps/$current_map.d/portals" "$underground_portal"
}

rects_overlap() {
    local ax=$1 ay=$2 aw=$3 ah=$4
    local bx=$5 by=$6 bw=$7 bh=$8

    (( ax < bx + bw && ax + aw > bx && ay < by + bh && ay + ah > by ))
}


generate_ruins() {
  local portal_ref="$1"

  local WIDTH=80
  local HEIGHT=40
  map_data=()
  local row
  row=$(printf 'a%.0s' $(seq 1 $WIDTH))
  for ((y = 0; y < HEIGHT; y++)); do
    map_data["$y"]="$row"
  done
  local TREE_COUNT=$(((WIDTH * HEIGHT) / 8))
  for ((i = 0; i < TREE_COUNT; i++)); do
    local x=$((RANDOM % WIDTH))
    local y=$((RANDOM % HEIGHT))
    ((RANDOM % 2)) && tree='T' || tree='t'
    line="${map_data[$y]}"
    map_data[$y]="${line:0:$x}${tree}${line:$((x + 1))}"
  done
RUINS=()
local ruin_count=$((3 + RANDOM % 4)) # 3–6 ruin
for ((r = 0; r < ruin_count; r++)); do
    local ok=0 attempts=0
    while ((attempts < 10)); do
        attempts=$((attempts + 1))
        local rx=$((RANDOM % (WIDTH - 12) + 2))
        local ry=$((RANDOM % (HEIGHT - 10) + 2))
        local rw=$((6 + RANDOM % 8))
        local rh=$((4 + RANDOM % 6))
        ok=1
        for ruin in "${RUINS[@]}"; do
            read -r ox oy ow oh <<< "$ruin"
            if rects_overlap "$rx" "$ry" "$rw" "$rh" "$ox" "$oy" "$ow" "$oh"; then
                ok=0
                break
            fi
        done
        ((ok == 1)) && break
    done
    ((ok == 0)) && continue
    RUINS+=("$rx $ry $rw $rh")
    for ((y = ry; y < ry + rh; y++)); do
      for ((x = rx; x < rx + rw; x++)); do
        if ((x == rx || x == rx + rw - 1 || y == ry || y == ry + rh - 1)); then
          line="${map_data[$y]}"
          map_data[$y]="${line:0:$x}W${line:$((x + 1))}"
        fi
      done
    done
    local holes=$(((rw + rh) / 2))
    for ((h = 0; h < holes; h++)); do
      case $((RANDOM % 4)) in
        0)
          hx=$((rx + RANDOM % rw))
          hy=$ry
          ;;
        1)
          hx=$((rx + RANDOM % rw))
          hy=$((ry + rh - 1))
          ;;
        2)
          hx=$rx
          hy=$((ry + RANDOM % rh))
          ;;
        3)
          hx=$((rx + rw - 1))
          hy=$((ry + RANDOM % rh))
          ;;
      esac
      line="${map_data[$hy]}"
      map_data[$hy]="${line:0:$hx}a${line:$((hx + 1))}"
    done
  done
  local target_map
  target_map="$(obj_get "$portal_ref" "target_map")"
  local MON_COUNT=$((5 + RANDOM % 5))
  for ((m = 0; m < MON_COUNT; m++)); do
    local id=1
    local used_ids
    while :; do
      local found=0
      local used
      for used in "${used_ids[@]}"; do
        [[ "$used" -eq "$id" ]] && found=1 && break
      done
      ((found == 0)) && break
      ((id++))
    done
    used_ids+=("$id")
    local mref
    printf -v mref "%smonster%03d" "$target_map" "$id"
    unset "$mref"
    declare -gA "$mref"
    create_random_monster_no_reg "$mref"
    while :; do
      local mx=$((RANDOM % WIDTH))
      local my=$((RANDOM % HEIGHT))
      tile="$(get_map_tile_xy "$mx" "$my")"
      tile_is_passable "$tile" && break
    done
    obj_set "$mref" "x" "$mx"
    obj_set "$mref" "y" "$my"
    obj_store "$mref" "save/maps/$target_map.d/npcs" "$mref"
  done
  MAP_WIDTH=$WIDTH
  MAP_HEIGHT=$HEIGHT
  if (( ruin_count > 0 )); then
    local pick=$((RANDOM % ruin_count))
    local rparts=(${RUINS[$pick]})
    local rx="${rparts[0]}"
    local ry="${rparts[1]}"
    local rw="${rparts[2]}"
    local rh="${rparts[3]}"
    local cx=$((rx + rw / 2))
    local cy=$((ry + rh / 2))
    create_underground_portal "$portal_ref" "$cx" "$cy"
  fi
  save_map "$target_map"
  local target_x_g=$((WIDTH / 2))
  local target_y_g=$((HEIGHT / 2))
  obj_set "$portal_ref" "target_x" "$target_x_g"
  obj_set "$portal_ref" "target_y" "$target_y_g"
  return 0
}

fill_rect_with_t() {
    local x0=$1
    local y0=$2
    local w=$3
    local h=$4
    (( w <= 0 || h <= 0 )) && return
    for ((y = y0; y < y0 + h; y++)); do
        (( y < 0 || y >= MAP_HEIGHT )) && continue
        local row="${map_data[$y]}"
        for ((x = x0; x < x0 + w; x++)); do
            (( x < 0 || x >= MAP_WIDTH )) && continue
            row="${row:0:$x}t${row:$((x+1))}"
        done
        map_data[$y]="$row"
    done
}

generate_village() {
    local portal_ref="$1"
    local WIDTH=80
    local HEIGHT=60
    map_data=()
    local row
    row=$(printf 'a%.0s' $(seq 1 $WIDTH))
    for ((y=0; y<HEIGHT; y++)); do
        map_data[$y]="$row"
    done
    if (( RANDOM % 2 == 0 )); then
        gen_lake "$(( RANDOM % WIDTH ))" "$(( RANDOM % HEIGHT ))"
    fi
    local cx=$((WIDTH / 2))
    local cy=$((HEIGHT / 2))
    local sq_w=15
    local sq_h=9
    local sx=$((cx - sq_w / 2))
    local sy=$((cy - sq_h / 2))
    for ((y=sy; y<sy+sq_h; y++)); do
        ((y<0 || y>=HEIGHT)) && continue
        local line="${map_data[$y]}"
        for ((x=sx; x<sx+sq_w; x++)); do
            ((x<0 || x>=WIDTH)) && continue
            map_data[$y]="${line:0:$x}b${line:$((x+1))}"
            line="${map_data[$y]}"
        done
    done
    local house_count=$((3 + RANDOM % 3))
    declare -gA houses=()
    for ((i=0; i<house_count; i++)); do
        for attempt in {1..20}; do
            local hx=$((cx + (RANDOM % 13 - 6) * 4))
            local hy=$((cy + (RANDOM % 7 - 3) * 4))
            local hh=$((5 + RANDOM % 5))
            local hw=$((10 + RANDOM % 10))
            (( hx < 1 || hy < 1 || hx+hw >= WIDTH-1 || hy+hh >= HEIGHT-1 )) && continue
            local conflict=0
            for ((y=hy-1; y<=hy+hh; y++)); do
                for ((x=hx-1; x<=hx+hw; x++)); do
                    [[ "${map_data[$y]:$x:1}" != "a" ]] && conflict=1 && break 2
                done
            done
            ((conflict==1)) && continue
            houses["$i"]="$hx $hy $hw $hh"
            local mid_x=$((hx + hw / 2))
            local mid_y=$((hy + hh / 2))
            local door_x=$mid_x
            local door_y=$hy
            if ((cy > mid_y)); then door_y=$((hy + hh - 1)); fi
            for ((y=hy; y<hy+hh; y++)); do
                local line="${map_data[$y]}"
                for ((x=hx; x<hx+hw; x++)); do
                    if ((x == door_x && y == door_y)); then
                        map_data[$y]="${line:0:$x}b${line:$((x+1))}"
                    elif ((x == hx || x == hx+hw-1 || y == hy || y == hy+hh-1)); then
                        map_data[$y]="${line:0:$x}W${line:$((x+1))}"
                    else
                        map_data[$y]="${line:0:$x}b${line:$((x+1))}"
                    fi
                    line="${map_data[$y]}"
                done
            done
            break
        done
    done
    if (( RANDOM % 2 == 0 )); then
        local orchard_w=$((5 + RANDOM % 5))
        local orchard_h=$((5 + RANDOM % 5))
        local ox=$((RANDOM % (WIDTH - orchard_w)))
        local oy=$((RANDOM % (HEIGHT - orchard_h)))
        local ok=1
        for ((y=oy; y<oy+orchard_h; y++)); do
            for ((x=ox; x<ox+orchard_w; x++)); do
                [[ "${map_data[$y]:$x:1}" != "a" ]] && ok=0 && break 2
            done
        done
        ((ok==1)) && fill_rect_with_t "$ox" "$oy" "$orchard_w" "$orchard_h"
    fi
    local tree_count=$(( (WIDTH*HEIGHT)/50 ))
    for ((i=0; i<tree_count; i++)); do
        local x=$((RANDOM % WIDTH))
        local y=$((RANDOM % HEIGHT))
        [[ "${map_data[$y]:$x:1}" != "a" ]] && continue
        map_data[$y]="${map_data[$y]:0:$x}T${map_data[$y]:$((x+1))}"
    done
    MAP_WIDTH=$WIDTH
    MAP_HEIGHT=$HEIGHT
    obj_set "$portal_ref" "target_x" "$cx"
    obj_set "$portal_ref" "target_y" "$cy"
    local target_map
    target_map=$(obj_get "$portal_ref" "target_map")
    declare -g MERCHANT_SPAWNED=0
    local next_id=1
    for idx in "${!houses[@]}"; do
        read hx hy hw hh <<< "${houses[$idx]}"
        local mx my tries=0
        while :; do
            ((tries++))
            mx=$((hx + 1 + RANDOM % (hw - 2)))
            my=$((hy + 1 + RANDOM % (hh - 2)))
            [[ -z "$(npc_on_xy "$mx" "$my")" ]] && break
            ((tries > 50)) && break
        done
        local npc_ref
        printf -v npc_ref "%snpc%03d" "$target_map" "$next_id"
        ((next_id++))
        declare -gA "$npc_ref"
        if (( MERCHANT_SPAWNED == 0 && RANDOM % 3 == 0 )); then
            create_merchant_no_reg "$npc_ref"
            MERCHANT_SPAWNED=1
        else
            create_civilian_no_reg "$npc_ref"
        fi
        obj_set "$npc_ref" "x" "$mx"
        obj_set "$npc_ref" "y" "$my"
        obj_store "$npc_ref" "save/maps/$target_map.d/npcs" "$npc_ref"
    done
    save_map "$target_map"
}

generate_town() {
    local portal_ref="$1"
    local WIDTH=140
    local HEIGHT=80
    map_data=()
    local row
    row=$(printf 'a%.0s' $(seq 1 $WIDTH))
    for ((y=0; y<HEIGHT; y++)); do
        map_data["$y"]="$row"
    done
if (( RANDOM % 2 == 0 )); then
    local lx=$(( RANDOM % WIDTH ))
    local ly=$(( RANDOM % HEIGHT ))
    gen_lake "$lx" "$ly"
fi
local cx=$((WIDTH / 2))
local cy=$((HEIGHT / 2))
local sq_w=15
local sq_h=9
local sx=$((cx - sq_w / 2))
local sy=$((cy - sq_h / 2))
for ((y=sy; y<sy+sq_h && y<HEIGHT; y++)); do
    local line="${map_data[$y]}"
    for ((x=sx; x<sx+sq_w && x<WIDTH; x++)); do
        map_data[$y]="${line:0:$x}e${line:$((x+1))}"
        line="${map_data[$y]}"
    done
done
local sides=("top" "bottom" "left" "right")
for side in "${sides[@]}"; do
    local street_len=$((15 + RANDOM % 11))
    case "$side" in
        top)
            local y=$((sy-1))
            [[ $y -lt 0 ]] && continue
            local x=$((sx + RANDOM % (sq_w - 1)))
            for ((s=0; s<street_len && y>=0; s++)); do
                for w in 0 1; do
                    [[ $((x+w)) -lt WIDTH ]] && map_data[$y]="${map_data[$y]:0:$((x+w))}e${map_data[$y]:$((x+w+1))}"
                done
                ((y--))
            done
            ;;
        bottom)
            local y=$((sy + sq_h))
            [[ $y -ge HEIGHT ]] && continue
            local x=$((sx + RANDOM % (sq_w - 1)))
            for ((s=0; s<street_len && y<HEIGHT; s++)); do
                for w in 0 1; do
                    [[ $((x+w)) -lt WIDTH ]] && map_data[$y]="${map_data[$y]:0:$((x+w))}e${map_data[$y]:$((x+w+1))}"
                done
                ((y++))
            done
            ;;
        left)
            local x=$((sx-1))
            [[ $x -lt 0 ]] && continue
            local y=$((sy + RANDOM % (sq_h - 1)))
            for ((s=0; s<street_len && x>=0; s++)); do
                for w in 0 1; do
                    [[ $((y+w)) -lt HEIGHT ]] && map_data[$((y+w))]="${map_data[$((y+w))]:0:$x}e${map_data[$((y+w))]:$((x+1))}"
                done
                ((x--))
            done
            ;;
        right)
            local x=$((sx + sq_w))
            [[ $x -ge WIDTH ]] && continue
            local y=$((sy + RANDOM % (sq_h - 1)))
            for ((s=0; s<street_len && x<WIDTH; s++)); do
                for w in 0 1; do
                    [[ $((y+w)) -lt HEIGHT ]] && map_data[$((y+w))]="${map_data[$((y+w))]:0:$x}e${map_data[$((y+w))]:$((x+1))}"
                done
                ((x++))
            done
            ;;
    esac
done
    local house_count=$((10 + RANDOM % 6))
    declare -gA houses
    houses=()
    for ((i=0; i<house_count; i++)); do
        local placed=0
        for attempt in {1..10}; do
            local hx=$((cx + (RANDOM % 25 - 12) * 3))
            local hy=$((cy + (RANDOM % 13 - 6) * 3))
            local hh=$((5 + RANDOM % 5))
            local hw=$((10 + RANDOM % 10))
            (( hx < 1 || hy < 1 || hx+hw > WIDTH-1 || hy+hh > HEIGHT-1 )) && continue
            local conflict=0
            for ((y=hy-1; y<=hy+hh && y<HEIGHT; y++)); do
                local row="${map_data[$y]}"
                for ((x=hx-1; x<=hx+hw && x<WIDTH; x++)); do
                    [[ "${row:$x:1}" != "a" ]] && conflict=1 && break 2
                done
            done
            (( conflict == 1 )) && continue
            placed=1
            houses["$i"]="$hx $hy $hw $hh"
            local mid_x=$((hx + hw / 2))
            local mid_y=$((hy + hh / 2))
            local left_dist=$(( cx - hx ))
            local right_dist=$(( (hx + hw - 1) - cx ))
            local top_dist=$(( cy - hy ))
            local bottom_dist=$(( (hy + hh - 1) - cy ))
            local door_x=-1 door_y=-1
            if (( left_dist > 0 && left_dist <= right_dist )); then
                door_x=$((hx + hw - 1)); door_y=$mid_y
            elif (( right_dist > 0 )); then
                door_x=$hx; door_y=$mid_y
            elif (( top_dist > 0 )); then
                door_x=$mid_x; door_y=$((hy + hh - 1))
            else
                door_x=$mid_x; door_y=$hy
            fi
            for ((y=hy; y<hy+hh && y<HEIGHT; y++)); do
                local row="${map_data[$y]}"
                for ((x=hx; x<hx+hw && x<WIDTH; x++)); do
                    if (( x == hx || x == hx+hw-1 || y == hy || y == hy+hh-1 )); then
                        if (( x == door_x && y == door_y )); then
                           map_data[$y]="${row:0:$x}e${row:$((x+1))}"
                        else
                           map_data[$y]="${row:0:$x}W${row:$((x+1))}"
                        fi
                    else
                        map_data[$y]="${row:0:$x}e${row:$((x+1))}"
                    fi
                    row="${map_data[$y]}"
                done
            done
            break
        done
    done
if (( RANDOM % 2 == 0 )); then
    local orchard_w=$(( 5 + RANDOM % 5 ))
    local orchard_h=$(( 5 + RANDOM % 5 ))
    local ox=$(( RANDOM % (WIDTH - orchard_w) ))
    local oy=$(( RANDOM % (HEIGHT - orchard_h) ))
    local ok=1
    for ((y=oy; y<oy+orchard_h; y++)); do
        for ((x=ox; x<ox+orchard_w; x++)); do
            local check="${map_data[$y]}"
            [[ "${check:$x:1}" != "a" ]] && ok=0 && break 2
        done
    done
    (( ok == 1 )) && fill_rect_with_t "$ox" "$oy" "$orchard_w" "$orchard_h"
fi
    local tree_count=$(( (WIDTH*HEIGHT)/50 ))
    for ((i=0; i<tree_count; i++)); do
        local x=$((RANDOM % WIDTH))
        local y=$((RANDOM % HEIGHT))
        [[ "${map_data[$y]:$x:1}" != "a" ]] && continue
        local tile=$((RANDOM % 2))
        [[ $tile -eq 0 ]] && tile="T" || tile="t"
        map_data[$y]="${map_data[$y]:0:$x}${tile}${map_data[$y]:$((x+1))}"
    done
    MAP_WIDTH=$WIDTH
    MAP_HEIGHT=$HEIGHT
    obj_set "$portal_ref" "target_x" "$cx"
    obj_set "$portal_ref" "target_y" "$cy"
    target_map=$(obj_get "$portal_ref" "target_map")
declare -g MERCHANT_SPAWNED
MERCHANT_SPAWNED=0
for idx in "${!houses[@]}"; do
    read hx hy hw hh <<< "${houses[$idx]}"
    local mx my
    while :; do
        mx=$(( hx + 1 + RANDOM % (hw - 2) ))
        my=$(( hy + 1 + RANDOM % (hh - 2) ))
        [[ -z "$(npc_on_xy "$mx" "$my")" ]] && break
    done
    local npc_type="villager"
    if (( MERCHANT_SPAWNED == 0 && RANDOM % 3 == 0 )); then
        npc_type="merchant"
        MERCHANT_SPAWNED=1
    fi
    local id=1
    local used_ids
    while :; do
        local found=0
        for used in "${used_ids[@]}"; do
            [[ "$used" -eq "$id" ]] && found=1 && break
        done
        ((found == 0)) && break
        ((id++))
    done
    used_ids+=("$id")
    local npc_ref
    printf -v npc_ref "%snpc%03d" "$target_map" "$id"
    unset "$npc_ref"
    declare -gA "$npc_ref"
    if [[ "$npc_type" == "merchant" ]]; then
        create_merchant_no_reg "$npc_ref"
    else
        create_civilian_no_reg "$npc_ref"
    fi
    player_ref="player_ref"
    obj_set "$npc_ref" "x" "$mx"
    obj_set "$npc_ref" "y" "$my"
    obj_store "$npc_ref" "save/maps/$target_map.d/npcs" "$npc_ref"
done
    save_map "$target_map"
}

generate_map() {
  local portal_ref="$1"
  local subtype
  subtype=$(obj_get "$portal_ref" "subtype")
  case "$subtype" in
    0)
      generate_dungeon "$portal_ref"
      ;;
    1)
      generate_ruins "$portal_ref"
      ;;
    2)
      generate_village "$portal_ref"
      ;;
    3)
      generate_town "$portal_ref"
      ;;
    *)
      generate_dungeon "$portal_ref"
      ;;
  esac
}

check_portal() {
  local x y
  x=$(get_player_stat "x")
  y=$(get_player_stat "y")
  local portal
  portal=$(iterate_over_portals_par "portal_on_xy_helper" "$x" "$y")
  if [[ -z "$portal" ]]; then
    print_ui "" "There is nothing to enter"
    return 1
  fi
  local subtype icon
  subtype=$(obj_get "$portal" "subtype")
  icon=$(obj_get "$portal" "icon")
  if (( subtype != 0 )) && [[ "$icon" != "E" ]]; then
    set_player_stat "lastx" "$x"
    set_player_stat "lasty" "$y"
  fi
  local target_map
  target_map=$(obj_get "$portal" "target_map")
  if [[ ! -f "save/maps/$target_map" ]]; then
    print_ui "" "Generating map..."
    draw_interface
    draw
    unload_items
    unload_npcs
    generate_map "$portal"
  fi
  local target_x_g target_y_g
  target_x_g=$(obj_get "$portal" "target_x")
  target_y_g=$(obj_get "$portal" "target_y")
  local portal_name
  portal_name=$(obj_get "$portal" "name")
  change_map "$target_map" "$subtype"
  if [[ "$subtype" -eq 0 ]]; then
    local level
    level=$(obj_get "$portal" "level")
    print_ui "" "You entered $portal_name level $level"
  else
    print_ui "" "You entered $portal_name"
  fi
  set_player_stat "location" "$portal_name"
  set_player_stat "x" "$target_x_g"
  set_player_stat "y" "$target_y_g"
 if [[ "$subtype" -eq 2 || "$subtype" -eq 3 ]]; then
   set_player_stat "safe_location" "$portal_name"
   set_player_stat "safe_map" "$target_map"
   set_player_stat "safe_x" "$target_x_g"
   set_player_stat "safe_y" "$target_y_g"
   set_player_stat "safe_subtype" "$subtype"
   local safe_lastx safe_lasty
   safe_lastx=$(get_player_stat "lastx")
   safe_lasty=$(get_player_stat "lasty")
   set_player_stat "safe_lastx" "$safe_lastx"
   set_player_stat "safe_lasty" "$safe_lasty"
 fi
  return 0
}

gen_portal_name() {
  local portal_ref="$1"
  local subtype
  subtype=$(obj_get "$portal_ref" "subtype")
  local roots=("Alder" "Frost" "Oak" "Wolf" "Iron" "Silver" "Green" "Stone" "Moon" "Raven" "Dark" "Gold" "Red" "High" "Low" "Dragon" "Star" "Wind")
  local village_suffix=("shire" "dale" "field" "stead" "brook")
  local town_suffix=("ville" "ford" "gate" "port" "burg")
  local dungeon_suffix=("Crypt" "Catacombs" "Pit" "Abyss" "Lair")
  local ruins_suffix=("Ruins" "Remnants" "Collapse" "Ruined Halls")
  local name root suf
  root=${roots[$((RANDOM % ${#roots[@]}))]}
  case "$subtype" in
    0)
      suf=${dungeon_suffix[$((RANDOM % ${#dungeon_suffix[@]}))]}
      name="$root $suf"
      ;;
    1)
      suf=${ruins_suffix[$((RANDOM % ${#ruins_suffix[@]}))]}
      name="$root $suf"
      ;;
    2)
      suf=${village_suffix[$((RANDOM % ${#village_suffix[@]}))]}
      name="${root}${suf}"
      ;;
    3)
      suf=${town_suffix[$((RANDOM % ${#town_suffix[@]}))]}
      name="${root}${suf}"
      ;;
    *)
      name="${root}Land" # fallback
      ;;
  esac
  obj_set "$portal_ref" "name" "$name"
}

create_portal_icon() {
  local portal_ref="$1"
  local subtype
  subtype=$(obj_get "$portal_ref" "subtype")
  local icon
  case "$subtype" in
    0) icon="D" ;; # dungeon
    1) icon="R" ;; # ruins
    2) icon="V" ;; # village
    3) icon="T" ;; # town
    *) icon="?" ;; # fallback
  esac
  obj_set "$portal_ref" "icon" "$icon"
}

create_random_portal() {
  get_portal_obj_ref
  local portal_ref="$assigned_portal_ref"
  create_blank_object "$portal_ref"
  local player_x player_y
  player_x=$(get_player_stat "x")
  player_y=$(get_player_stat "y")
  local x y tile dx dy jitter
  while :; do
    dx=$(((RANDOM % 5) + 4)) # 4–8
    dy=$(((RANDOM % 5) + 4)) # 4–8
    ((RANDOM % 2)) && dx=$((-dx))
    ((RANDOM % 2)) && dy=$((-dy))
    jitter=$((RANDOM % 3 - 1)) # -1, 0, 1
    dx=$((dx + jitter))
    jitter=$((RANDOM % 3 - 1))
    dy=$((dy + jitter))
    x=$((player_x + dx))
    y=$((player_y + dy))
    ((x >= 0 && x < MAP_WIDTH && y >= 0 && y < MAP_HEIGHT)) || continue
    local portal_ref2
    portal_ref2=$(portal_on_xy "$x" "$y")
    if is_space_free "$x" "$y" && [[ -z "$portal_ref2" ]]; then
        break
    fi

   done
  obj_set "$portal_ref" "x" "$x"
  obj_set "$portal_ref" "y" "$y"
  local subtype=$((RANDOM % 4))
  obj_set "$portal_ref" "subtype" "$subtype"
  obj_set "$portal_ref" "map" "overworld"
  obj_set "$portal_ref" "map_type" 4
  obj_set "$portal_ref" "location" "overworld"
  create_portal_icon "$portal_ref"
  gen_portal_name "$portal_ref"
  get_map_name
  obj_set "$portal_ref" "target_map" "$assigned_map_name"
  register_portal "$portal_ref"
  case "$subtype" in
    0) print_ui "" "You have discovered a dark dungeon entrance..." ;;
    1) print_ui "" "You stumbled upon ancient ruins!" ;;
    2) print_ui "" "You found a small village in the distance!" ;;
    3) print_ui "" "A bustling town awaits beyond this portal!" ;;
  esac
}


draw_portal() {
    local portal_ref=$1
    local px=$2
    local py=$3
    declare -n IT="$portal_ref"
    local x=${IT[x]}
    local y=${IT[y]}
    if ! in_viewport "$x" "$y"; then
        return 0
    fi
    local vx=$(( x - px + VIEWPORT_WIDTH/2 ))
    local vy=$(( y - py + VIEWPORT_HEIGHT/2 ))
    printf "%d;%d;%s\n" "$vx" "$vy" "${IT[icon]}"
}

draw_portals() {
  local px=$PLAYER_X
  local py=$PLAYER_Y
  local line vx vy icon
  while IFS=';' read -r vx vy icon; do
    FRAME_BUFFER["$vx,$vy"]="\e[37m${icon}"
  done < <(iterate_over_portals_par "draw_portal" "$px" "$py")
}

gen_lake() {
  local WIDTH=$1
  local HEIGHT=$2
  local lake_w=$((5 + RANDOM % 16)) # 5–20
  local lake_h=$((5 + RANDOM % 16))
  local x0=$((RANDOM % (WIDTH - lake_w)))
  local y0=$((RANDOM % (HEIGHT - lake_h)))
  local x y
  for ((y = y0; y < y0 + lake_h; y++)); do
    for ((x = x0; x < x0 + lake_w; x++)); do
      local dx=$((RANDOM % 3 - 1)) # -1,0,1
      local dy=$((RANDOM % 3 - 1))
      local nx=$((x + dx))
      local ny=$((y + dy))
      ((nx < 0)) && nx=0
      ((ny < 0)) && ny=0
      ((nx >= WIDTH)) && nx=$((WIDTH - 1))
      ((ny >= HEIGHT)) && ny=$((HEIGHT - 1))
      local line="${map_data[$ny]}"
      map_data["$ny"]="${line:0:$nx}c${line:$((nx + 1))}"
    done
  done
}

gen_mountain() {
  local WIDTH=$1
  local HEIGHT=$2
  local lake_w=$((15 + RANDOM % 16)) # 5–20
  local lake_h=$((15 + RANDOM % 16))
  local x0=$((RANDOM % (WIDTH - lake_w)))
  local y0=$((RANDOM % (HEIGHT - lake_h)))
  local x y
  for ((y = y0; y < y0 + lake_h; y++)); do
    for ((x = x0; x < x0 + lake_w; x++)); do
      local dx=$((RANDOM % 3 - 1)) # -1,0,1
      local dy=$((RANDOM % 3 - 1))
      local nx=$((x + dx))
      local ny=$((y + dy))
      ((nx < 0)) && nx=0
      ((ny < 0)) && ny=0
      ((nx >= WIDTH)) && nx=$((WIDTH - 1))
      ((ny >= HEIGHT)) && ny=$((HEIGHT - 1))
      local line="${map_data[$ny]}"
      map_data["$ny"]="${line:0:$nx}d${line:$((nx + 1))}"
    done
  done
}

generate_overworld() {
  local WIDTH=1500
  local HEIGHT=1500
  local TREE_COUNT=225000
  local count=0
  local row
  map_data=()
  local total_grass=$HEIGHT
  local last_percent=-1
  row=$(printf 'a%.0s' $(seq 1 $WIDTH))
  for ((y = 0; y < HEIGHT; y++)); do
    map_data["$y"]="$row"
    local percent=$(((y * 100) / total_grass))
    if ((percent != last_percent)); then
      echo -ne "Generating grass... $percent%\r"
      last_percent=$percent
    fi
  done
  echo ""
  local last_tree_percent=-1
  while ((count < TREE_COUNT)); do
    local x=$((RANDOM % WIDTH))
    local y=$((RANDOM % HEIGHT))
    local line="${map_data["$y"]}"
    local current="${line:$x:1}"
    [[ "$current" != "a" ]] && continue
    ((RANDOM % 2)) && tree='T' || tree='t'
    map_data["$y"]="${line:0:$x}${tree}${line:$((x + 1))}"
    ((count++))
    local percent=$(((count * 100) / TREE_COUNT))
    if ((percent != last_tree_percent)); then
      echo -ne "Generating trees... $percent%\r"
      last_tree_percent=$percent
    fi
  done
  echo ""
  local LAKE_COUNT=2250
  local last_lake_percent=-1
  for ((i = 1; i <= LAKE_COUNT; i++)); do
    gen_lake "$WIDTH" "$HEIGHT"
    local percent=$(((i * 100) / LAKE_COUNT))
    if ((percent != last_lake_percent)); then
      echo -ne "Generating lakes... $percent%\r"
      last_lake_percent=$percent
    fi
  done
 echo ""
  local MOUNTAIN_COUNT=225
  local last_mountain_percent=-1
  for ((i = 1; i <= MOUNTAIN_COUNT; i++)); do
    gen_mountain "$WIDTH" "$HEIGHT"
    local percent=$(((i * 100) / MOUNTAIN_COUNT))
    if ((percent != last_mountain_percent)); then
      echo -ne "Generating mountains... $percent%\r"
      last_mountain_percent=$percent
    fi
  done
  echo ""
  MAP_WIDTH=$WIDTH
  MAP_HEIGHT=$HEIGHT
  save_map "overworld"
  mkdir -p save/maps/overworld.d
  echo "Overworld generation completed!"
}

load_overworld() {
  change_map "overworld" 4
}
