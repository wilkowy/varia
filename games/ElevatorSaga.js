{
	init: function(elevators, floors) {
		const loadFactorOK = 0.75;
		const midHalt = true;

		const distance = function(floorNum1, floorNum2) {
			return Math.abs(floorNum1 - floorNum2);
		}

		floors._callIdleElevator = function(/*floorNum*/) {
			this.forEach(function(floor) {
				const floorNum = floor.floorNum();
				if (elevators.some( elevator => elevator._hasDestination(floorNum) )) {
					return;
				}
				const idleElevators = [];
				elevators.forEach(function(elevator) {
					if (elevator.destinationQueue.length == 0) {
						idleElevators.push(elevator);
					}
				});
				if (idleElevators.length > 0) {
					const closestIdleElevator = idleElevators.sort(
							(elevatorA, elevatorB) => distance(elevatorA.currentFloor(), floorNum) - distance(elevatorB.currentFloor(), floorNum)
						).shift();
					closestIdleElevator.goToFloor(floorNum);
					//closestIdleElevator._updateIndicators(floorNum);
					floor._requestedUp = false;
					floor._requestedDown = false;
				}
			});
		}

		/*
		let getClosestCall = function(elevator) {
			let currentFloor = elevator.currentFloor();
			//floors._waitingQueue.filter(function(floorNum) {
			//	return distance(currentFloor, floorNum) < maxDistance;
			//});
			return floors._waitingQueue.sort(
					(floorNumA, floorNumB) => distance(floorNumA, currentFloor) - distance(floorNumB, currentFloor)
				).shift();
		};
		*/

		floors.forEach(function(floor, floorIndex) {
			floor._index = floorIndex;
			floor._requestedUp = false;
			floor._requestedDown = false;

			floor.on("up_button_pressed", function() {
				this._requestedUp = true;
				floors._callIdleElevator(); // or lowest loadFactor?
			});

			floor.on("down_button_pressed", function() {
				this._requestedDown = true;
				floors._callIdleElevator();
			});
		});

		elevators.forEach(function(elevator, elevatorIndex) {
			elevator._index = elevatorIndex;

			elevator._sortDestinations = function(floorNum) {
				return this.destinationQueue.sort( (floorNumA, floorNumB) => distance(floorNumA, floorNum) - distance(floorNumB, floorNum) )[0];
			}

			elevator._hasDestination = function(floorNum) {
				return this.destinationQueue.includes(floorNum); // indexOf != -1
			};

			elevator._removeDestination = function(floorNum) {
				if (this._hasDestination(floorNum)) {
					this.destinationQueue.splice(this.destinationQueue.indexOf(floorNum), 1); // .filter
				}
			}

			elevator._setIndicators = function(state) {
				this.goingUpIndicator(state);
				this.goingDownIndicator(state);
			};

			elevator._updateIndicators = function(floorNum) {
				const currentFloor = this.currentFloor();
				if (floorNum > currentFloor) {
					this.goingUpIndicator(true);
					this.goingDownIndicator(false);
				} else if (floorNum < currentFloor) {
					this.goingUpIndicator(false);
					this.goingDownIndicator(true);
				} else {
					this._setIndicators(false);
				}
			};

			elevator.on("idle", function() {
				const currentFloor = this.currentFloor();
				const floorsWithRequests = floors.filter( floor => (floor._requestedUp || floor._requestedDown) );
				if (floorsWithRequests.length > 0) {
					const closestCallFloor = floorsWithRequests.sort(
							(floorA, floorB) => distance(floorA.floorNum(), currentFloor) - distance(floorB.floorNum(), currentFloor)
						).shift();
					closestCallFloorNum = closestCallFloor.floorNum();
					//if (currentFloor != closestCallFloorNum) {
						this.goToFloor(closestCallFloorNum);
						//this._updateIndicators(closestCallFloorNum);
						closestCallFloor._requestedUp = false;
						closestCallFloor._requestedDown = false;
					//} else {
						//this._setIndicators(true);
					//}
				} else {
					//let randomFloor = Math.floor(Math.random() * floors.length);
					this.goToFloor(0);
					floors[0]._requestedUp = false;
					floors[0]._requestedDown = false;
					//this._setIndicators(true);
				}
			});

			elevator.on("floor_button_pressed", function(floorNum) {
				if (!this._hasDestination(floorNum)) {
					this.goToFloor(floorNum);
					this._sortDestinations(floorNum);
					this.checkDestinationQueue();
					//this._updateIndicators(floorNum);
				}
			});

			elevator.on("passing_floor", function(floorNum, direction) {
				if (this._hasDestination(floorNum) ||
					(midHalt && this.loadFactor() <= loadFactorOK &&
					((direction == "up" && floors[floorNum]._requestedUp) || (direction == "down" && floors[floorNum]._requestedDown)))) {
					// && this.destinationQueue.length <= Math.floor(this.maxPassengerCount() * 2 / 3)
					this._removeDestination(floorNum);
					this.goToFloor(floorNum, true);
					//this.checkDestinationQueue();
					//this._setIndicators(???);
				}
			});

			elevator.on("stopped_at_floor", function(floorNum) {
				//this._setIndicators(true);
				if (this.destinationDirection() == "up") {
					floors[floorNum]._requestedUp = false;
				} else {
					floors[floorNum]._requestedDown = false;
				}
				this._sortDestinations(floorNum);
				this.checkDestinationQueue();
			});
		});
	},

	update: function(dt, elevators, floors) {
		//console.log('dt: ' + dt);
	}
}
