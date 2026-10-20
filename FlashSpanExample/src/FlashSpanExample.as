/* Copyright 2011, Eric Mika

This file is part of FlashSpan.

FlashSpan is free software: you can redistribute it and/or modify
it under the terms of the GNU Lesser General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

FlashSpan is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public License
along with FlashSpan.  If not, see <http://www.gnu.org/licenses/>. */

package {
    import com.bit101.components.FPSMeter;
    import com.bit101.components.Label;
    import com.bit101.components.PushButton;
    import com.kitschpatrol.flashspan.FlashSpan;
    import com.kitschpatrol.flashspan.Settings;
    import com.kitschpatrol.flashspan.events.CustomMessageEvent;
    import com.kitschpatrol.flashspan.events.FlashSpanEvent;
    import com.kitschpatrol.flashspan.events.FrameSyncEvent;

    import flash.desktop.NativeApplication;
    import flash.display.Sprite;
    import flash.display.StageAlign;
    import flash.display.StageScaleMode;
    import flash.events.Event;
    import flash.events.InvokeEvent;
    import flash.events.MouseEvent;
    import flash.events.TimerEvent;
    import flash.utils.Timer;

    public class FlashSpanExample extends Sprite {
        private var flashSpan:FlashSpan;
        private var canvas:Sprite;
        private var status:Label;
        private var fpsMeter:FPSMeter;
        private var balls:Array = [];
        private var screenID:int;
        private var lastTime:int = 0;
        private var initialized:Boolean = false;
        private var startTimer:Timer;

        public function FlashSpanExample() {
            NativeApplication.nativeApplication.addEventListener(InvokeEvent.INVOKE, onInvoke);
        }

        private function onInvoke(e:InvokeEvent):void {
            if (initialized) return;
            initialized = true;
            screenID = e.arguments.length > 0 ? int(e.arguments[0]) : -1;
            flashSpan = new FlashSpan(screenID);
            screenID = flashSpan.settings.thisScreen.id;
            stage.scaleMode = StageScaleMode.NO_SCALE;
            stage.align = StageAlign.TOP_LEFT;
            stage.frameRate = flashSpan.settings.frameRate;
            // Set the content area independently of each OS's title bar size.
            stage.nativeWindow.width += flashSpan.settings.screenWidth - stage.stageWidth;
            stage.nativeWindow.height += flashSpan.settings.screenHeight - stage.stageHeight;

            canvas = new Sprite();
            canvas.x = -flashSpan.settings.thisScreen.x;
            canvas.graphics.beginFill(0xE8E8E8);
            canvas.graphics.drawRect(0, 0, flashSpan.settings.totalWidth, flashSpan.settings.totalHeight);
            canvas.graphics.endFill();
            addChild(canvas);
            canvas.addEventListener(MouseEvent.CLICK, onCanvasClick);

            var panel:Sprite = new Sprite();
            panel.graphics.beginFill(0xFFFFFF);
            panel.graphics.drawRect(0, 0, flashSpan.settings.screenWidth, 112);
            panel.graphics.endFill();
            addChild(panel);
            new Label(panel, 12, 8, "FLASHSPAN / SCREEN " + screenID + " / " + flashSpan.settings.syncMode + " sync");
            status = new Label(panel, 12, 34, "Waiting for Start");
            fpsMeter = new FPSMeter(panel, flashSpan.settings.screenWidth - 68, 8);
            fpsMeter.start();
            var start:PushButton = button(panel, 12, 62, "Start");
            start.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):void { flashSpan.start(); });
            var stop:PushButton = button(panel, 86, 62, "Stop");
            stop.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):void { flashSpan.stop(); });
            var add:PushButton = button(panel, 160, 62, "+ Balls");
            add.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):void { flashSpan.broadcastCustomMessage("a"); });
            var clear:PushButton = button(panel, 234, 62, "Clear");
            clear.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):void { flashSpan.broadcastCustomMessage("c"); });
            var quit:PushButton = button(panel, 308, 62, "Quit All");
            quit.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):void { flashSpan.quitAll(); });
            new Label(panel, 12, 92, "Click below to add a ball across all screens.");

            flashSpan.addEventListener(FlashSpanEvent.START, onStart);
            flashSpan.addEventListener(FlashSpanEvent.STOP, onStop);
            flashSpan.addEventListener(FrameSyncEvent.SYNC, onFrameSync);
            flashSpan.addEventListener(CustomMessageEvent.MESSAGE_RECEIVED, onMessage);
            addBalls();
            trace("READY screen=" + screenID);
            if (screenID == 0 && e.arguments.indexOf("--autostart") >= 0) {
                startTimer = new Timer(1000, 1);
                startTimer.addEventListener(TimerEvent.TIMER_COMPLETE, function(event:TimerEvent):void { flashSpan.start(); });
                startTimer.start();
            }
        }

        private function button(parent:Sprite, x:Number, y:Number, text:String):PushButton {
            var control:PushButton = new PushButton(parent, x, y, text);
            control.setSize(68, 26);
            return control;
        }

        private function onCanvasClick(e:MouseEvent):void {
            flashSpan.broadcastCustomMessage("m", canvas.mouseX + "," + canvas.mouseY);
        }

        private function onMessage(e:CustomMessageEvent):void {
            if (e.header == "a") addBalls();
            else if (e.header == "c") {
                while (balls.length > 0) canvas.removeChild(balls.pop());
            } else if (e.header == "m") {
                var point:Array = e.message.split(",");
                addBall(Number(point[0]), Number(point[1]));
            }
            trace("MESSAGE screen=" + screenID + " header=" + e.header + " balls=" + balls.length);
        }

        private function onStart(e:Event):void {
            trace("START screen=" + screenID);
            if (flashSpan.settings.syncMode == Settings.SYNC_TIME) addEventListener(Event.ENTER_FRAME, onTimeFrame);
        }

        private function onStop(e:Event):void {
            trace("STOP screen=" + screenID);
            status.text = "Stopped / " + balls.length + " balls";
            lastTime = 0;
            removeEventListener(Event.ENTER_FRAME, onTimeFrame);
        }

        private function onFrameSync(e:FrameSyncEvent):void {
            updateBalls(1);
            status.text = balls.length + " balls / UDP localhost / Frame " + e.frameCount;
            if (e.frameCount % 60 == 0) {
                // Deterministic state lets demo-check verify animation across processes.
                var state:String = "";
                for each (var ball:Ball in balls) state += ball.x.toFixed(3) + "," + ball.y.toFixed(3) + ";";
                trace("SYNC screen=" + screenID + " frame=" + e.frameCount + " state=" + state);
            }
        }

        private function onTimeFrame(e:Event):void {
            var time:int = flashSpan.getTime();
            if (lastTime > 0) updateBalls((time - lastTime) * flashSpan.settings.frameRate / 1000);
            lastTime = time;
            status.text = "Server time " + time + " ms / " + balls.length + " balls";
        }

        private function addBalls():void {
            for (var i:int = 0; i < 10; i++) {
                addBall(flashSpan.random.random() * (flashSpan.settings.totalWidth - Ball.DIAMETER),
                    120 + flashSpan.random.random() * (flashSpan.settings.totalHeight - 120 - Ball.DIAMETER));
            }
        }

        private function addBall(x:Number, y:Number):void {
            var ball:Ball = new Ball(uint(flashSpan.random.random() * 0xFFFFFF));
            ball.x = x;
            ball.y = y;
            ball.vx = flashSpan.random.float(-8, 8);
            ball.vy = flashSpan.random.float(-8, 8);
            canvas.addChild(ball);
            balls.push(ball);
        }

        private function updateBalls(step:Number):void {
            for each (var ball:Ball in balls) {
                ball.x += ball.vx * step;
                ball.y += ball.vy * step;
                if (ball.x + ball.width > flashSpan.settings.totalWidth) {
                    ball.x = flashSpan.settings.totalWidth - ball.width;
                    ball.vx = -Math.abs(ball.vx);
                } else if (ball.x < 0) {
                    ball.x = 0;
                    ball.vx = Math.abs(ball.vx);
                }
                if (ball.y + ball.height > flashSpan.settings.totalHeight) {
                    ball.y = flashSpan.settings.totalHeight - ball.height;
                    ball.vy = -Math.abs(ball.vy);
                } else if (ball.y < 114) {
                    ball.y = 114;
                    ball.vy = Math.abs(ball.vy);
                }
            }
        }
    }
}
