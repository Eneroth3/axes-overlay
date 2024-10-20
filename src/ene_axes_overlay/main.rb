module Eneroth
  module EnerothAxesOverlay
    # Vary superclass depending on whether this SketchUp version has overlays.
    super_class = defined?(Sketchup::Overlay) ? Sketchup::Overlay : Object

    class AxesDisplay < super_class
      # Distance between axes widget and edge of screen
      MARGIN = 20

      # Size of axes widget in logical screen pixels.
      RADIUS = 70

      def initialize
        if defined?(Sketchup::Overlay)
          super(PLUGIN_ID, EXTENSION.name, description: EXTENSION.description)
        end
      end

      # Use Both Tool and Overlay API to make the extension work in old SU
      # versions.

      # @api sketchup-observers
      # https://ruby.sketchup.com/Sketchup/Tool.html
      def activate
        Sketchup.active_model.active_view.invalidate
      end

      # @api sketchup-observers
      # https://ruby.sketchup.com/Sketchup/Tool.html
      def resume(view)
        view.invalidate
      end

      # @api sketchup-observers
      # @see https://ruby.sketchup.com/Sketchup/Overlay.html
      # @see https://ruby.sketchup.com/Sketchup/Tool.html
      def draw(view)
        tr = widget_transformation(view)

        # TODO: Extract method for setting axes colors. Honor drawing axes directions.
        view.set_color_from_line(ORIGIN, ORIGIN.offset(X_AXIS))
        view.line_stipple = ""
        points = [ORIGIN, Geom::Point3d.new(RADIUS, 0, 0)]
        view.draw2d(GL_LINES, points.map { |pt| pt.transform(tr) })

        view.line_stipple = "."
        points = [ORIGIN, Geom::Point3d.new(-RADIUS, 0, 0)]
        view.draw2d(GL_LINES, points.map { |pt| pt.transform(tr) })

        view.set_color_from_line(ORIGIN, ORIGIN.offset(Y_AXIS))
        view.line_stipple = ""
        points = [ORIGIN, Geom::Point3d.new(0, RADIUS, 0)]
        view.draw2d(GL_LINES, points.map { |pt| pt.transform(tr) })
        view.line_stipple = "."
        points = [ORIGIN, Geom::Point3d.new(0, -RADIUS, 0)]
        view.draw2d(GL_LINES, points.map { |pt| pt.transform(tr) })

        view.set_color_from_line(ORIGIN, ORIGIN.offset(Z_AXIS))
        view.line_stipple = ""
        points = [ORIGIN, Geom::Point3d.new(0, 0, RADIUS)]
        view.draw2d(GL_LINES, points.map { |pt| pt.transform(tr) })
        view.line_stipple = "."
        points = [ORIGIN, Geom::Point3d.new(0, 0, -RADIUS)]
        view.draw2d(GL_LINES, points.map { |pt| pt.transform(tr) })
      end

      # Get transformation compass internal coordinates to screen space coordinates
      # TODO: Update all these descriptions
      #
      # @param view [Sketchup::View]
      #
      # @return [Geom::Transformation]
      def widget_transformation(view)
        # TODO: Calculate properly
        Geom::Transformation.new(widget_center(view))# *
          #Geom::Transformation.rotation(ORIGIN, Z_AXIS, compass_angle(view))
      end

      # Screen space position of compass center.
      #
      # @param view [Sketchup::View]
      #
      # @return [Geom::Poin3d]
      def widget_center(view)
        # Change here to change the position of the axes overlay on screen.
        bottom_left_corner = Geom::Point3d.new(*view.corner(2), 0)

        bottom_left_corner.offset([RADIUS + MARGIN, -RADIUS - MARGIN, 0])
      end
    end

    if defined?(Sketchup::Overlay)
      # If SketchUp has Overlays API, use it.
      class OverlayAttacher < Sketchup::AppObserver
        def expectsStartupModelNotifications
          true
        end

        def register_overlay(model)
          overlay = AxesDisplay.new
          model.overlays.add(overlay)
        end
        alias_method :onNewModel, :register_overlay
        alias_method :onOpenModel, :register_overlay
      end

      observer = OverlayAttacher.new
      Sketchup.add_observer(observer)

      observer.register_overlay(Sketchup.active_model)
    else
      # For legacy SketchUp, fall back on Tool API and menu item.
      unless @loaded
        @loaded = true

        menu = UI.menu("Plugins")
        menu.add_item(EXTENSION.name) { Sketchup.active_model.select_tool(AxesDisplay.new) }
      end
    end
  end
end
