require 'rubygems'
require 'gosu'

# TODO: Point[0, 0]

class Point < Struct.new(:x, :y)
  def rotate_around(center, angle)
    diff = Point.new(self.x - center.x, self.y - center.y)
    Point.new(center.x + diff.x * Math.cos(angle) - diff.y * Math.sin(angle), 
              center.y + diff.x * Math.sin(angle) + diff.y * Math.cos(angle))
  end
  
  def distance_to(point)
    Math.hypot point.x - self.x, point.y - self.y
  end
  
  def to_screen
    Point.new(320 + self.x, 240 - self.y)
  end
  
  def to_radius
    Vector.new(self.x, self.y)
  end
  
  def to_s
    "(#{self.x}, #{self.y})"
  end  
end

class Vector < Struct.new(:x, :y)
  def self.by_end_points(origin_point, end_point)
    self.new(end_point.x - origin_point.x, end_point.y - origin_point.y)
  end
  
  def modulus      
    Math.hypot(x ,y)
  end

  def scalar_product(vector)
    x * vector.x + y * vector.y
  end
  
  def rotate(angle)
    self.to_point.rotate_around(Point.new(0, 0), angle).to_radius
  end
  
  def +(vector)
    Vector.new(x + vector.x, y + vector.y)
  end
  
  def angle_with(vector)
    cos_alpha = self.scalar_product(vector) / (self.modulus * vector.modulus)
    Math.acos(cos_alpha)
  end
  
  def to_point
    Point.new(self.x, self.y)
  end
end

class Line < Struct.new(:point1, :point2)
  def intersection_point_with(line)
    # raise if overlaps?(line)
    
    numerator = (line.point1.y - point1.y) * (line.point1.x - line.point2.x) -
      (line.point1.y - line.point2.y) * (line.point1.x - point1.x);
    denominator = (point2.y - point1.y) * (line.point1.x - line.point2.x) - 
      (line.point1.y - line.point2.y) * (point2.x - point1.x);

    t = numerator.to_f / denominator;
    
    x = point1.x + t * (point2.x - point1.x)
    y = point1.y + t * (point2.y - point1.y)            
    
    Point.new(x, y)
  end
  
  def angle_with(line)
    self.to_vector.angle_with(line.to_vector)
  end
  
  def to_vector
    Vector.by_end_points(self.point1, self.point2)
  end
end

class Segment < Struct.new(:point1, :point2)
  def middle_point
    Point.new(
      (point2.x - point1.x).to_f / 2,
      (point2.y - point1.y).to_f / 2
    )
  end
end

class Player
  attr_reader :position, :angle
  
  def angle=(value)
    @angle = value % (2 * Math::PI)
  end
  
  def position=(point)
    @position.x = point.x# % 640
    @position.y = point.y# % 480
  end
  
  # Tracks model
  
  attr_accessor :left_track_power, :right_track_power
  
  attr_accessor :intersection_point, :advanced_track_axis, :rotated_center, :middle_point, :new_track_axis
  
  def axis_lenghth
    40
  end
  
  def track_axis
     Line.new(left_track, right_track)
  end

  def move_tracks(distance)
    if (left_track_power - right_track_power).abs <= Float::EPSILON * 2
      @position = Point.new(@position.x, @position.y + distance * left_track_power).rotate_around(@position, @angle)
    else
      left_track_delta = Vector.new(0, distance * left_track_power).rotate(@angle)
      right_track_delta = Vector.new(0, distance * right_track_power).rotate(@angle)

      advanced_left_track = (left_track.to_radius + left_track_delta).to_point
      advanced_right_track = (right_track.to_radius + right_track_delta).to_point
      
      self.advanced_track_axis = Line.new(advanced_left_track, advanced_right_track)

      angle_delta = track_axis.angle_with(advanced_track_axis)
      self.intersection_point = track_axis.intersection_point_with(advanced_track_axis)

      next_left_track_position = left_track.rotate_around(intersection_point, angle_delta)
      next_right_track_position = right_track.rotate_around(intersection_point, angle_delta)

      self.rotated_center = position.rotate_around(intersection_point, angle_delta)
      self.middle_point = Segment.new(next_left_track_position, next_right_track_position).middle_point

      puts rotated_center.distance_to(middle_point)

      self.position = middle_point
      self.angle += angle_delta
      
      x_axis = Vector.new(1, 0)
      self.new_track_axis = Line.new(next_left_track_position, next_right_track_position)

      puts (self.angle - x_axis.angle_with(new_track_axis.to_vector))
    end
  end
  
  # Drawing
  
  def unangled_left_track
    Point.new(@position.x - axis_lenghth / 2, @position.y)
  end
  
  def unangled_right_track
    Point.new(@position.x + axis_lenghth / 2, @position.y)
  end
  
  def left_track
    unangled_left_track.rotate_around(@position, @angle)
  end

  def right_track
    unangled_right_track.rotate_around(@position, @angle)
  end
  
  def draw_track(center)
    side_length = 8.to_f
    corners = [Point.new(center.x - side_length / 2, center.y - side_length / 2),
               Point.new(center.x + side_length / 2, center.y - side_length / 2),
               Point.new(center.x + side_length / 2, center.y + side_length / 2),
               Point.new(center.x - side_length / 2, center.y + side_length / 2)]
    corners.map! { |point| point.rotate_around(@position, @angle) }
    @window.rectangle(corners)
  end

  def draw
    @window.line(track_axis)
    
    @window.triangle(Point.new(@position.x - 3, @position.y).rotate_around(@position, @angle),
                     Point.new(@position.x, @position.y + 5.2).rotate_around(@position, @angle),
                     Point.new(@position.x + 3, @position.y).rotate_around(@position, @angle))
    #draw_track(unangled_left_track)
    #draw_track(Point.new(@position.x + axis_lenghth / 2, @position.y))
    
    @window.line(Line.new(Point.new(-200, 0), Point.new(200, 0)), 0xf0333333)
    @window.line(Line.new(Point.new(0, -200), Point.new(0, 200)), 0xf0333333)
    
    @window.line(Line.new(self.intersection_point, self.advanced_track_axis.point1), 0xf00aaff0)
    @window.square(self.intersection_point, 6, 0xf00aaff0)
    
    @window.square(self.middle_point, 4, 0xf00ff000)
    @window.square(self.rotated_center, 4, 0xf0ff0000)
    #@window.line(self.new_track_axis, 0xf0ff0000)
  end

  def turn_clock_wise(delta)
    self.angle -= delta
  end

  def turn_counter_clock_wise(delta)
    self.angle += delta
  end
  
  def initialize(window)
    @position = Point.new(0, 0)
    @angle = 0
    @left_track_power = 0.7
    @right_track_power = 1
        
    @window = window
  end
end

class GameWindow < Gosu::Window
  def initialize
    super(640, 480, false)
    self.caption = "Tracks"

    @player = Player.new(self)
    @player.move_tracks(1)

    @lines = []
    3.times { @lines << Gosu::Font.new(self, Gosu::default_font_name, 20) }
  end

  def default_color
    0xffffff00
  end

  def line(line, color=default_color)
    draw_line(line.point1.to_screen.x, line.point1.to_screen.y, color, line.point2.to_screen.x, line.point2.to_screen.y, color)
  end
  
  def triangle(point1, point2, point3)
    draw_triangle(point1.to_screen.x, point1.to_screen.y, default_color, 
                  point2.to_screen.x, point2.to_screen.y, default_color, 
                  point3.to_screen.x, point3.to_screen.y, default_color)
  end
  
  def rectangle(corners, color=default_color)
    draw_quad(corners[0].to_screen.x, corners[0].to_screen.y, color,
              corners[1].to_screen.x, corners[1].to_screen.y, color,
              corners[2].to_screen.x, corners[2].to_screen.y, color,
              corners[3].to_screen.x, corners[3].to_screen.y, color)
  end
  
  def square(center, side_length, color=default_color)
    side_length = side_length.to_f
    corners = [Point.new(center.x - side_length / 2, center.y - side_length / 2),
               Point.new(center.x + side_length / 2, center.y - side_length / 2),
               Point.new(center.x + side_length / 2, center.y + side_length / 2),
               Point.new(center.x - side_length / 2, center.y + side_length / 2)]    
    self.rectangle(corners, color)
  end

  def update
    if button_down? Gosu::KbLeft
    #  @player.turn_counter_clock_wise(3 * Math::PI / 180) # 5.radians
    end

    if button_down? Gosu::KbRight
     # @player.turn_clock_wise(3 * Math::PI / 180)
    end

    if button_down? Gosu::KbUp
      @player.move_tracks(1)
    end       
  end

  def draw
    @player.draw

    @lines[0].draw("position: (#{@player.position.x.to_i}, #{@player.position.y.to_i}) angle: #{(@player.angle * 180 / Math::PI).to_i} ", 10, 10, 3, 1.0, 1.0, default_color)
    @lines[1].draw("track power: [#{@player.left_track_power}, #{@player.right_track_power}]", 10, 30, 3, 1.0, 1.0, default_color)
    @lines[2].draw("left track: (#{@player.left_track.x.to_i}, #{@player.left_track.y.to_i}), right track: (#{@player.right_track.x.to_i}, #{@player.right_track.y.to_i})", 10, 50, 3, 1.0, 1.0, default_color)
  end

  def button_down(id)
    if id == Gosu::KbEscape then
      close
    end
  end
end

GameWindow.new.show