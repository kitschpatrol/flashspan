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
	import com.bit101.components.*;
	import com.demonsters.debugger.MonsterDebugger;
	import com.kitschpatrol.flashspan.FlashSpan;
	import com.kitschpatrol.flashspan.Settings;
	import com.kitschpatrol.flashspan.SpanSprite;
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
	import flash.utils.getTimer;

	public class FlashSpanExample extends Sprite {
		
		private var flashSpan:FlashSpan;		
		private var spanSprite:SpanSprite;
		
		private var titleLabel:Label;
		private var syncLabel:Label;
		private var eventLabel:Label;
		private var fpsMeter:FPSMeter;
		
		private const ballCount:int = 10; 		
		private var balls:Array = [];		
		
		private var lastTime:int = 0;		
		
		public function FlashSpanExample() {
			// catch command line args
			NativeApplication.nativeApplication.addEventListener(InvokeEvent.INVOKE, onInvoke);						
		}
			
		private function onInvoke(e:InvokeEvent):void {
			MonsterDebugger.initialize(this);
			MonsterDebugger.trace(this, "Command line args: " + e.arguments);
			
			// assume an incoming arg is a screen ID override
			// useful for testing on a single machine,
			// in production the automatic ID from IP is probably better
			
			if  (e.arguments.length > 0) {
				var screenID:int = e.arguments[0];
				flashSpan = new FlashSpan(screenID);	
			}
			else {
				flashSpan = new FlashSpan(flashSpan.getIDfromIP(), "E:\flash_span_settings.xml");
			}
			
			// set up the stage, make sure it's the correct size (some padding seems to get thrown in by the OS)
			stage.scaleMode = StageScaleMode.NO_SCALE;
			stage.align = StageAlign.TOP;			
			stage.nativeWindow.width = flashSpan.settings.thisScreen.screenWidth;
			stage.nativeWindow.height = flashSpan.settings.thisScreen.screenHeight + 20; // compensate for title bar			
			
			// the span sprite, includes automatic translation compensation
			spanSprite = flashSpan.getSpanSprite();
			addChild(spanSprite);
			
			// set up the GUI
			fpsMeter = new FPSMeter();
			fpsMeter.start();
			
			titleLabel = new Label(this, 5, 5, "FlashSpan Example\nClick anywhere to add a ball. Using " + flashSpan.settings.syncMode + " sync mode.");
			titleLabel.textField.textColor = 0x000000;
			syncLabel = new Label(this, 5, 35, "Waiting To start.\tFPS: " + fpsMeter.fps);
			eventLabel = new Label(this, 5, 50, "");

			
			
			new PushButton(this, 5, 70, "Start", onStartButton);
			new PushButton(this, 5, 95, "Stop", onStopButton);
			new PushButton(this, 5, 120, "Add Balls", onAddBallsButton);
			new PushButton(this, 5, 145, "Clear Balls", onClearBallsButton);
			new PushButton(this, 5, 170, "Quit All", onQuitButton);			

			// listen for events from FlashSpan
			flashSpan.addEventListener(FlashSpanEvent.START, onStart);
			flashSpan.addEventListener(FlashSpanEvent.STOP, onStop);
			flashSpan.addEventListener(CustomMessageEvent.MESSAGE_RECEIVED, onCustomMessageReceived);
			
			// only listen for frame sync if we're using that instead of time mode
			if (flashSpan.settings.syncMode == Settings.SYNC_FRAMES) {
				flashSpan.addEventListener(FrameSyncEvent.SYNC, onFrameSync);
			}			
			
			// listen for local events, these will get passed on through a FlashSpan custom message
			spanSprite.addEventListener(MouseEvent.CLICK, onMouseClick);
			
			// add some initial balls
			addBalls();
		}		
		
		
		// For Time based updates
		private function onEnterFrame(e:Event):void {
			syncLabel.text = "Local Time: " + getTimer() + "\tServer Time: " + flashSpan.getTime() + "\tFPS: " + fpsMeter.fps;
			updateBallsByTime();
		}
		
		
		// UI Event Callbacks
		private function onStartButton(e:Event):void {
			flashSpan.start();
		}
		
		private function onStopButton(e:Event):void {
			flashSpan.stop();
		}
		
		private function onAddBallsButton(e:Event):void {
			flashSpan.broadcastCustomMessage("a");
		}
		
		private function onClearBallsButton(e:Event):void {
			flashSpan.broadcastCustomMessage("c");			
		}
		
		private function onQuitButton(e:Event):void {
			flashSpan.quitAll();
		}		
		
		private function onMouseClick(e:MouseEvent):void {
			// send a CSV of mouse X and Y coordinates to everyone
			flashSpan.broadcastCustomMessage("m", e.localX + "," + e.localY);
		}
		
		
		// FlashSpan Event Callbacks
		private function onCustomMessageReceived(e:CustomMessageEvent):void {
			eventLabel.text = "Custom message event fired: ";
			
			if (e.header == "m") {
				// it's a mouse click
				eventLabel.text += "Mouse Click";
				
				var mousePosition:Array = e.message.split(",");
				var mx:int = mousePosition[0];
				var my:int = mousePosition[1];
				
				// Add a new ball at the mouse
				var ball:Ball = new Ball(0x000000);
				ball.x = mx - (ball.width / 2);
				ball.y = my - (ball.height / 2);
				ball.vx = (flashSpan.random() > 0.5) ? -flashSpan.random() * 15 : flashSpan.random() * 15;
				ball.vy = (flashSpan.random() > 0.5) ? -flashSpan.random() * 15 : flashSpan.random() * 15;				
				spanSprite.addChild(ball);
				balls.push(ball);
			}
			else if (e.header == "a") {
				eventLabel.text += "Add Balls";
				// it's a ball request
				addBalls();
			}
			else if (e.header == "c") {
				eventLabel.text += "Clear Balls";
				
				// remove all the balls
				while (balls.length > 0) {
					spanSprite.removeChild(balls.pop());
				}
			}			
		}
		
		private function onStart(e:Event):void {
			eventLabel.text = "Start event fired";

			// If we're using time, then use local frame callback
			if (flashSpan.settings.syncMode == Settings.SYNC_TIME) {
				addEventListener(Event.ENTER_FRAME, onEnterFrame);
			}
		}
		
		private function onStop(e:Event):void {
			eventLabel.text = "Stop event fired";			
			
			if (flashSpan.settings.syncMode == Settings.SYNC_TIME) {			
				removeEventListener(Event.ENTER_FRAME, onEnterFrame);
			}
		}		
		
		private function onFrameSync(e:FrameSyncEvent):void {
			syncLabel.text = "Frame number: " + e.frameCount + "\tFPS: " + fpsMeter.fps;
			updateBallsByFrame();
		}
		
		
		// Ball Simulation Stuff
		private function updateBallsByFrame():void {
			// update the balls by one frame
			for (var i:int = 0; i < balls.length; i++) {
				var ball:Ball = balls[i];
				
				ball.x += ball.vx;
				ball.y += ball.vy;				
				
				// bounce off edges
				handleCollisions(ball);				
			}
		}
		
		private function updateBallsByTime():void {
			if (lastTime > 0) {
				var elapsed:int = flashSpan.getTime() - lastTime;
				
				// update the balls by one frame
				for (var i:int = 0; i < balls.length; i++) {
					var ball:Ball = balls[i];
					
					ball.x += (ball.vx * (elapsed / 100));
					ball.y += (ball.vy * (elapsed / 100));				
					
					// bounce off edges
					handleCollisions(ball);				
				}			
			}
			
			lastTime = flashSpan.getTime();
		}
		
		private function handleCollisions(ball:Ball):void {
			// left and right
			if ((ball.x + ball.width) > spanSprite.totalWidth) {
				ball.x = spanSprite.totalWidth - ball.width;
				ball.vx *= -1;
			}
			else if (ball.x < 0) {
				ball.x = 0;
				ball.vx *= -1;
			}
			
			// top and bottom
			if ((ball.y + ball.height) > spanSprite.totalHeight) {
				ball.y = spanSprite.totalHeight - ball.height;
				ball.vy *= -1;
			}
			else if (ball.y < 0) {
				ball.y = 0;
				ball.vy *= -1;
			}			
		}
		
		private function addBalls():void {
			for (var i:int = 0; i < ballCount; i++) {
				var ball:Ball = new Ball(flashSpan.random() * uint.MAX_VALUE);
				ball.x = flashSpan.random() * (spanSprite.totalWidth - ball.width);
				ball.y = flashSpan.random() * (spanSprite.totalHeight - ball.height);
				ball.vx = (flashSpan.random() > 0.5) ? -flashSpan.random() * 15 : flashSpan.random() * 15;
				ball.vy = (flashSpan.random() > 0.5) ? -flashSpan.random() * 15 : flashSpan.random() * 15;				
				spanSprite.addChild(ball);
				balls.push(ball); 
			}			
		}		
					
	}
}