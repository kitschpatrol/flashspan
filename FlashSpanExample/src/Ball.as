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
	import flash.display.Sprite;
	
	public class Ball extends Sprite {
		public static const DIAMETER:int = 40;
		
		public var vx:Number;
		public var vy:Number;	
		
		public function Ball(color:uint) {
			super();
			this.graphics.beginFill(color);
			this.graphics.drawEllipse(0, 0, DIAMETER, DIAMETER);
			this.graphics.endFill();
		}
	}
}
