library ui;

import 'dart:async' show StreamSubscription;
import 'dart:html';

import 'package:pixelcycle2/src/movie.dart' show WIDTH, HEIGHT, LARGE, ALL, Movie, Frame, Size;
import 'package:pixelcycle2/src/player.dart' show Player;

void onLoad(Player player) {
  Movie movie = player.movie;

  for (CanvasElement elt in queryAll('canvas[class="frameview"]')) {
    var size = new Size(elt.attributes["data-size"]);
    var f = new FrameView(elt, size);
    player.onTimeChange.listen((num time) {
      f.frame = player.currentFrame;
    });
  }

  for (CanvasElement elt in queryAll('canvas[class="stripview"]')) {
    var size = new Size(elt.attributes["data-size"]);
    var strip = new StripView(elt, size, player);
    player.onTimeChange.listen((num time) {
      strip.render(player.positionAt(time));
    });
  }
}

class FrameView {
  final CanvasElement elt;
  final Size size;
  Frame _frame;

  FrameView(this.elt, this.size) {
    elt.width = WIDTH * size.pixelsize;
    elt.height = HEIGHT * size.pixelsize;
  }

  /// Sets the current frame. Renders the frame if it changed.
  set frame(Frame newFrame) {
    if (_frame == newFrame) {
      return;
    }
    _frame = newFrame;
    _frame.render(elt.context2D, size, ALL);
  }
}

const SPACER = 10;

class StripView {
  final CanvasElement elt;
  final Size size;
  final Player player;
  final int height = HEIGHT + SPACER;

  StreamSubscription moveSub;
  num lastTime;
  num lastY;

  var touchId = null;
  StreamSubscription touchMoveSub;
  num lastTouchTime;
  num lastTouchY;

  StripView(this.elt, this.size, this.player) {
    elt.width = WIDTH + SPACER * 2;
    elt.height = HEIGHT * LARGE.pixelsize;
    elt.style.backgroundColor = "#000000";

    elt.onMouseDown.listen((e) {
      e.preventDefault();
      player.playing = false;
      player.velocity = 0;
      if (moveSub == null) {
        lastTime = window.performance.now() / 1000.0;
        lastY = e.client.y;
        moveSub = elt.onMouseMove.listen(drag);
      }
    });

    elt.onMouseUp.listen((e) => stopDragging());
    elt.onMouseOut.listen((e) => stopDragging());
    query("body").onMouseUp.listen((e) => stopDragging());

    elt.onTouchStart.listen((TouchEvent e) {
      print("onTouchStart");
      e.preventDefault();
      if (touchId != null) {
        return; // ignore touches after the first
      }
      Touch t = e.changedTouches[0];
      player.playing = false;
      player.velocity = 0;
      if (touchMoveSub == null) {
        touchId = t.identifier;
        lastTouchTime = window.performance.now() / 1000.0;
        lastTouchY = t.page.y;
        print("lastTouchY: ${lastTouchY}");
        touchMoveSub = elt.onTouchMove.listen(touchDrag);
      }
    });

    elt.onTouchEnd.listen((TouchEvent e) {
      if (e.touches.isEmpty) {
        print("onTouchEnd empty");
        stopDragging();
      }
    });
  }

  void drag(MouseEvent e) {
    num now = window.performance.now() / 1000.0;
    num deltaY = e.client.y - lastY;
    num deltaPos = -deltaY / height;
    num deltaT = now - lastTime;
    player.drag(deltaPos, deltaT);
    lastTime = now;
    lastY = e.client.y;
  }

  void touchDrag(TouchEvent e) {
    for (Touch t in e.changedTouches) {
      if (t.identifier == touchId) {
        num now = window.performance.now() / 1000.0;
        num deltaY = t.page.y - lastTouchY;
        num deltaPos = -deltaY / height;
        num deltaT = now - lastTouchTime;
        player.drag(deltaPos, deltaT);
        lastTouchTime = now;
        lastTouchY = t.page.y;
      }
    }
  }

  void stopDragging() {
    player.playing = true;
    if (moveSub != null) {
      moveSub.cancel();
      moveSub = null;
    }
    if (touchMoveSub != null) {
      touchMoveSub.cancel();
      touchMoveSub = null;
    }
    touchId = null;
  }

  void render(num moviePosition) {
    var movie = player.movie;
    elt.width = elt.width;
    var c = elt.context2D;

    int currentFrame = moviePosition ~/ 1;
    int currentFrameY = elt.height ~/ 2;

    num startPos = (moviePosition - currentFrameY / height) % movie.frames.length;
    int frame = startPos ~/ 1;
    int frameY = ((frame - startPos) * height) ~/ 1 + SPACER ~/ 2;
    while (frameY < elt.height) {
      var peakDist = (frameY - currentFrameY).abs() / elt.height;
      c.globalAlpha = 0.6 - peakDist / 2;
      movie.frames[frame].renderAt(c, size, SPACER, frameY);

      frame = (frame + 1) % movie.frames.length;
      frameY += height;
    }

    c.strokeStyle = "#FFF";
    c.globalAlpha = 1.0;
    c.moveTo(0, currentFrameY);
    c.lineTo(elt.width, currentFrameY);
    c.stroke();
  }
}

