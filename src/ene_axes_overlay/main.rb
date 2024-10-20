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

        # Axes currently don't cater to perspective and their position within
        # the view.
        # REVIEW: Consider using 3D model space for placing the widget in front
        # of the physical camera. Can then rely on View#screen_coords and 2D
        # drawing to always draw on top of the model.

        view.line_width = 1
        3.times do |axis_index|
          set_color_from_axis(view, axis_index)

          view.line_stipple = ""
          points = [ORIGIN, ORIGIN.dup.tap { |pt| pt[axis_index] = RADIUS }]
          view.draw2d(GL_LINES, points.map { |pt| pt.transform(tr) })

          view.line_stipple = "."
          points = [ORIGIN, ORIGIN.dup.tap { |pt| pt[axis_index] = -RADIUS }]
          view.draw2d(GL_LINES, points.map { |pt| pt.transform(tr) })
        end
      end

      # Set view drawing color to one of the SketchUp axes colors.
      #
      # SketchUp has no native way to read the axis colors from user preferences.
      # If we don't just want to assume they are R, G and B, we have to wrap
      # View#set_color_from_line.
      #
      # @param view [Sketchup::View]
      # @param axis_index [Integer] 0, 1 and 2 for X, Y and Z axis respectively.
      def set_color_from_axis(view, axis_index)
        vector = view.model.axes.axes[axis_index]
        view.set_color_from_line(ORIGIN, ORIGIN.offset(vector))
      end

      # Get transformation from widget's internal coordinates to screen space
      # coordinates.
      #
      # @param view [Sketchup::View]
      #
      # @return [Geom::Transformation]
      def widget_transformation(view)
        Geom::Transformation.new(widget_center(view)) *
          # Screen space using negative Y for up
          Geom::Transformation.scaling(ORIGIN, 1, -1, 1) *
          Geom::Transformation.axes(ORIGIN, view.camera.xaxis, view.camera.yaxis, view.camera.zaxis).inverse *
          # REVIEW: Do we actually want the local or global axes when editing
          # group/component? Consider exposing as user setting.
          Geom::Transformation.axes(ORIGIN, *view.model.axes.axes)
      end

      # Screen space position of widget center.
      #
      # @param view [Sketchup::View]
      #
      # @return [Geom::Poin3d]
      def widget_center(view)
        # Change here to change the position of the axes overlay on screen.
        # REVIEW: Consider exposing corner, size and margin in UI.
        # Also applies to Eneroth North Arrow.
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
