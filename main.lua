-- A maze runner.
--
-- This program is a maze running game. There's not death, no time limits and
-- nothing in the way of story. Go from the green square to the red, little
-- golden square!
--
-- Inspired by https://love2d.org/wiki/Tutorial:Gridlocked_Player
--
-- Developed with love 0.8.0, straight out of bitbucket tip.


-- Pre-define some colors. Love doesn't have any built in and it's rather nice
-- to refer to color names.
white = { 255, 255, 255, 255 }
grey = { 128, 128, 128, 255 }
red = { 255, 0, 0, 255 }
green = { 0, 255, 0, 255 }
blue = { 0, 0, 255, 255 }
gold = { 255, 215, 0, 255 }

-- Defines the dimensions of the world. When possible, we refer only to grid
-- numbers, but love2d's calls require pixel values. base_size refers to the
-- width and height of one grid cell.
x_grid_max = 130
y_grid_max = 99
base_size = 8
width  = base_size*(x_grid_max+1)
height = base_size*(y_grid_max+1)
love.graphics.setMode( width, height )

-- All cells are one of three types, only OPEN is passable by the player and the
-- maze carving algorithm. The maze is surrounded by a 'moat' of water, which is
-- really just a hack to make the mathematics of this simplistic. No edge cases.
WATER = 2
WALL = 1
OPEN = 0

--
-- Framework Functions
--

-- love.load, well, loads all of the preliminary data for the program. 'player'
-- is what you might expect, 'maze' the object (is that the right lua term) that
-- holds the position of the 'start' and 'exit' squares and 'map' which is the
-- world in which the player will move.
--
-- I also set the random seed based on current time. Bit of a gripe: os.time
-- returns in millisecond range, meaning the random seed isn't going to be that
-- great.
--
function love.load()
   player = {
      grid_x = 1,
      grid_y = 1,
   }
   maze = {
      ["exit"] = {
         grid_x = x_grid_max - 1,
         grid_y = y_grid_max - 1
      },
      ["start"] = {
         grid_x = 1,
         grid_y = 1
      }
   }

   time = os.time()
   math.randomseed( time )

   map = generate_maze()
end

-- love.draw updates the screen for every tick. We first layer in the maze
-- itself from 'map', then drop in the exit, start and player squares. The
-- player is a tasteful gold, but not dangerous like Midas.
function love.draw()
   -- the maze
   for x=0, x_grid_max do
      for y=0, y_grid_max do
         if map[y][x] == OPEN then
            love.graphics.setColor( white )
            love.graphics.rectangle("fill", x * base_size, y * base_size, base_size, base_size)
         elseif map[y][x] == WALL then
            love.graphics.setColor( grey )
            love.graphics.rectangle("line", x * base_size, y * base_size, base_size, base_size)
         elseif map[y][x] == WATER then
            love.graphics.setColor( blue )
            love.graphics.rectangle("fill", x * base_size, y * base_size, base_size, base_size)
         end
      end
   end

   -- the exit
   love.graphics.setColor( red )
   love.graphics.rectangle("fill", maze.exit.grid_x*base_size, maze.exit.grid_y*base_size, base_size, base_size)

   -- the start
   love.graphics.setColor( green )
   love.graphics.rectangle("fill", maze.start.grid_x*base_size, maze.start.grid_y*base_size, base_size, base_size)

   -- the player
   love.graphics.setColor( gold )
   love.graphics.rectangle("fill", player.grid_x*base_size, player.grid_y*base_size, base_size, base_size)
end

-- love.keypressed handles inputs per tick; I handle only movement and
-- escaping. That lua doesn't have a switch statement is somewhat irking to me,
-- but I suppose love2d is meant for prototypes? I'm certainly inexperienced
-- with both the language and the library. I _think_ love.draw consumes a
-- powerful amount of CPU in re-drawing the maze per tick.
function love.keypressed(key)
   if key == "up" then
      if collide(-1, 0) then
         player.grid_y = player.grid_y - 1
      end
   elseif key == "down" then
      if collide(1, 0) then
         player.grid_y = player.grid_y + 1
      end
   elseif key == "left" then
      if collide(0, -1) then
         player.grid_x = player.grid_x - 1
      end
   elseif key == "right" then
      if collide(0, 1) then
         player.grid_x = player.grid_x + 1
      end
   elseif key == 'escape' then
      love.event.push('quit')
   end
end

--
-- Internal Functions
--

-- generate_maze does what you might think. The algorithm is something like
-- Prim's.
function generate_maze()
   -- fill map entirely
   map = {}
   for i=0, y_grid_max do
      map[i] = {}
      for j=0, x_grid_max do
         map[i][j] = WALL
      end
   end

   -- build the moat
   for i=0, y_grid_max do
      for j=0, x_grid_max do
         map[0][j] = WATER
         map[y_grid_max][j] = WATER
      end
      map[i][x_grid_max] = WATER
      map[i][0] = WATER
   end

   -- craft the maze
   map[maze.start.grid_y][maze.start.grid_x] = OPEN --mark the entrance

   ---- walls contains those positions known to be walls. The function index is
   ---- a hash of the (y,x) coordinates. The algorithm will strip one wall
   ---- randomly out of walls, possibly mark it as open space and, possibly, add
   ---- the neighbor cells into 'walls'.
   walls = {
      ["0102"] = { y=1, x=2 },
      ["0201"] = { y=2, x=1 }
   }
   seen =  { ["0101"] = { x=1, y=1 } }
   while next(walls) ~= nil do
      key = rand_key(walls)

      wall = walls[key]
      walls[key] = nil
      seen[key] = wall

      y = wall.y
      x = wall.x

      north      = is_open(map, y-1, x)
      south      = is_open(map, y+1, x)
      west       = is_open(map, y,   x-1)
      east       = is_open(map, y,   x+1)

      -- Directions are named in terms of the cardinal directions. Up and down
      -- the Y-axis is N/S, left and right on the X-axis is W/E. is_center
      -- asserts that any new OPEN space cannot join some tunnels, although it
      -- does not disallow diagonal OPEN cells, which I dislike the look of.
      is_center = (north and south) or (north and west) or (north and east) or
                  (south and west) or (south and east) or (east and west)

      if not is_center then
         map[y][x] = OPEN
         add_wall(walls, seen, map, y-1, x) -- north
         add_wall(walls, seen, map, y+1, x) -- south
         add_wall(walls, seen, map, y, x-1) -- east
         add_wall(walls, seen, map, y, x+1) -- west
      end
   end

   -- search for the exit
   for i=1, y_grid_max-1 do
      if map[i][x_grid_max-1] == OPEN then
         maze.exit.grid_y = i
      end
   end
   return map
end

-- Possibly add the wall at (y,x) into 'walls', unless it is not a WALL or is in
-- 'seen', meaning we've already ruled it out as a candidate to go OPEN.
function add_wall(walls, seen, map, y, x)
   key = string.format("%.2d%.2d", y, x)

   if (map[y][x] == WALL) and (seen[key] == nil) then
      walls[key] = { y=y, x=x }
   end
end

-- This seems like a bitterly ugly hack: pull a random key out of a given table.
function rand_key(hash)
   ks = {}
   for k,v in pairs(hash) do table.insert(ks, k) end
   return ks[math.random(1, #ks)]
end

-- Determines if a given cell is, indeed, OPEN.
function is_open(map, y, x)
   if map[y][x] == OPEN then
      return true
   else
      return false
   end
end

-- Has the player hit somthing? This function performs the check.
function collide(y, x)
   if map[player.grid_y + y][player.grid_x + x] ~= OPEN then
      return false
   end
   return true
end

