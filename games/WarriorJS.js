// "Baby steps" only
class Player {
	constructor() {
		this._health = 20; // warrior.maxHealth()
		this._healthOk = 19;
		this._seeEnemy = [];
		this._stairsAhead = false;
		this._captiveInBack = false;
		this._turn = 1;
	}

// captive			= 1 HP
// sludge			= 12 HP,	3(2) dmg,	1 rng		cc:3	r:4		dcc:6(4)	dr:0
// thick sludge		= 24 HP,	3 dmg,		1 rng		cc:5	r:8		dcc:12		dr:0
// archer			= 7 HP,		3 dmg,		2? rng		cc:2	r:3					dr:6
// wizard			= 3 HP,		11 dmg,		2? rng		cc:1	r:1					dr:0

// warrior.attack(?direction?)				- 5 dmg (3 dmg back), 1 rng
// warrior.shoot(?direction?)				- 3 dmg, 3 rng
// warrior.detonate(?direction?)			- 8 dmg, 1 rng, 4 dmg aoe

// warrior.feel(?direction?)				- 1 rng
// warrior.look(?direction?)	space[]		- 3 rng
// warrior.listen()				space[unit]

// warrior.rest()
// warrior.rescue(?direction?)
// warrior.walk(?direction?)
// warrior.bind()

// warrior.think(string)

// warrior.health()				number
// warrior.maxHealth()			number
// warrior.directionOfStairs()	string = (forward, backward, left, right)
// warrior.directionOf(space)	string = (forward, backward, left, right)

// space.getLocation()	number[] = [forward, right]
// space.isEmpty()		bool
// space.isStairs()		bool
// space.isWall()		bool
// space.isUnit()		bool
// space.getUnit()		unit / undefined

// unit.isBound()					bool
// unit.isEnemy()					bool
// unit.isUnderEffect('ticking')	bool

	playTurn(warrior) {
		//warrior.think('DEBUG: HP now: ' + warrior.health() + ', HP prev: ' + this._health);

		this._lookAround(warrior);

		if (this._isUnderAttack(warrior)) {
			if (this._isHurtBadly(warrior)) {
				//warrior.think('DEBUG: under attack, hurt badly, can\'t rest -> backward action');
				this._makeAction(warrior, 'backward', false);
			} else {
				//warrior.think('DEBUG: under attack, can\'t rest -> forward action');
				this._makeAction(warrior, 'forward', false);
			}
		} else {
			//warrior.think('DEBUG: forward action');
			this._makeAction(warrior, 'forward');
		}

		this._health = warrior.health();
		this._turn++;
	}

	_makeAction(warrior, direction, canrest = true) {
		if (this._seeEnemy.backward > 1) {
			warrior.shoot('backward');
		} else if (this._seeEnemy.forward > 1) {
			warrior.shoot('forward');
		//} else if (this._seeEnemy.left > 1) {
		//	warrior.shoot('left');
		//} else if (this._seeEnemy.right > 1) {
		//	warrior.shoot('right');
		} else if (canrest && this._health < this._healthOk && !this._stairsAhead && this._isHurt(warrior)) {
			warrior.rest();
		} else if (warrior.feel(direction).isWall() || this._captiveInBack) {
			warrior.pivot();
		} else if (warrior.feel(direction).isEmpty()) {
			warrior.walk(direction);
		} else if (warrior.feel(direction).getUnit().isBound()) {
			warrior.rescue(direction);
		} else {
			warrior.attack(direction);
		}
	}

	_isHurt(warrior) {
		return warrior.health() < warrior.maxHealth();
	}

	_isHurtBadly(warrior) {
		return warrior.health() < warrior.maxHealth() * 0.5;
	}

	_isUnderAttack(warrior) {
		return this._health > warrior.health();
	}

	_lookAround(warrior) {
		for (const side of ['forward', 'backward', 'left', 'right']) {
			let space = warrior.look(side).find(space => space.isUnit());
			if (space && space.getUnit().isEnemy()) {
				this._seeEnemy[side] = Math.abs(space.getLocation()[0]);
			} else {
				this._seeEnemy[side] = 0;
			}
		}

		let space = warrior.look('forward').find(space => space.isStairs() && !space.isUnit());
		this._stairsAhead = space ? true : false;

		space = warrior.look('backward').find(space => space.isUnit());
		this._captiveInBack = space && space.getUnit().isBound();
	}

	_oppositeDirection(direction) {
		switch (direction) {
			case 'forward':		return 'backward';	break;
			case 'backward':	return 'forward';	break;
			case 'left':		return 'right';		break;
			case 'right':		return 'left';		break;
			default:								break;
		}
	}
}

/*
class Player {
	constructor() {
		this._turn = 1;
	}

	playTurn(warrior) {
		const ai = [];
		let action = ai[this._turn - 1];

		switch (action) {
			case 'w':	warrior.walk();				break;
			case 'wb':	warrior.walk('backward');	break;
			case 'wl':	warrior.walk('left');		break;
			case 'wr':	warrior.walk('right');		break;
			case 'p':	warrior.pivot();			break;
			case 'r':	warrior.rescue();			break;
			case 'rb':	warrior.rescue('backward');	break;
			case 'rl':	warrior.rescue('left');		break;
			case 'rr':	warrior.rescue('right');	break;
			case 'a':	warrior.attack();			break;
			case 'ab':	warrior.attack('backward');	break;
			case 'al':	warrior.attack('left');		break;
			case 'ar':	warrior.attack('right');	break;
			case 's':	warrior.shoot();			break;
			case 'sb':	warrior.shoot('backward');	break;
			case 'b':	warrior.bind();				break;
			case 'bb':	warrior.bind('backward');	break;
			case 'bl':	warrior.bind('left');		break;
			case 'br':	warrior.bind('right');		break;
			case 't':	warrior.rest();				break;
			default:	//warrior.think('???');
		}
		this._turn++;
	}
}
*/
