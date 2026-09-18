(() => {
  "use strict";

  const C = {
    W: 1280, H: 720,
    arena: { x: 36, y: 76, w: 1208, h: 598 },
    runDuration: 180,
    playerSpeed: 280, playerRadius: 15, maxHp: 5, iFrame: 0.7,
    blinkDistance: 150, blinkDuration: 0.12, blinkCooldown: 2,
    unitDamage: 10, unitInterval: 0.8, unitRange: 650, follow: 8,
    projectileSpeed: 620, projectileRadius: 4,
    enemyHp: 20, enemySpeed: 76, enemyRadius: 13, enemyMax: 160,
    spawnStart: 0.70, roundDuration: 30, spawnGrowth: 2,
    orbAttract: 150, orbCollect: 22, orbSpeed: 360,
    cyan: "#51f6d2", cyanDim: "#1b8e89", white: "#f3fbff",
    red: "#ff4f70", redDim: "#8f2949", yellow: "#ffd166",
    bg: "#07101f", grid: "#16304b", gridMajor: "#224661"
  };

  const canvas = document.getElementById("game");
  const ctx = canvas.getContext("2d", { alpha: false });
  const upgradeOverlay = document.getElementById("upgrade-overlay");
  const upgradeTitle = document.getElementById("upgrade-title");
  const upgradeCards = document.getElementById("upgrade-cards");
  const pauseOverlay = document.getElementById("pause-overlay");
  const resultOverlay = document.getElementById("result-overlay");
  const resultTitle = document.getElementById("result-title");
  const resultStats = document.getElementById("result-stats");

  const clamp = (value, min, max) => Math.max(min, Math.min(max, value));
  const length = (x, y) => Math.hypot(x, y);
  const distanceSq = (a, b) => (a.x - b.x) ** 2 + (a.y - b.y) ** 2;
  const lerp = (a, b, t) => a + (b - a) * t;
  const pad = (n, width = 2) => String(Math.max(0, Math.floor(n))).padStart(width, "0");
  const rgba = (hex, alpha) => {
    const value = parseInt(hex.slice(1), 16);
    return `rgba(${value >> 16},${(value >> 8) & 255},${value & 255},${alpha})`;
  };

  class Game {
    constructor() {
      this.keys = new Set();
      this.justPressed = new Set();
      this.lastFrame = performance.now();
      this.accumulator = 0;
      this.best = Number(localStorage.getItem("frctl-swarm-best") || 0);
      this.bindInput();
      this.reset();
      requestAnimationFrame((time) => this.frame(time));
    }

    bindInput() {
      const blocked = new Set(["ArrowUp", "ArrowDown", "ArrowLeft", "ArrowRight", "Space"]);
      window.addEventListener("keydown", (event) => {
        if (blocked.has(event.code)) event.preventDefault();
        if (!this.keys.has(event.code)) this.justPressed.add(event.code);
        this.keys.add(event.code);

        if (event.code === "Escape") this.togglePause();
        if (this.state === "upgrading" && ["Digit1", "Digit2", "Digit3"].includes(event.code)) {
          const index = Number(event.code.slice(-1)) - 1;
          this.chooseUpgrade(this.currentOptions[index]);
        } else if (this.state === "ended" && ["Enter", "Space", "KeyR"].includes(event.code)) {
          this.reset();
        }
      }, { passive: false });
      window.addEventListener("keyup", (event) => this.keys.delete(event.code));
      window.addEventListener("blur", () => {
        this.keys.clear();
        if (this.state === "playing") this.togglePause();
      });

      canvas.addEventListener("pointerdown", () => canvas.focus());
      document.getElementById("restart-button").addEventListener("click", () => this.reset());
      document.getElementById("resume-button").addEventListener("click", () => this.togglePause());
      document.getElementById("touch-blink").addEventListener("pointerdown", (event) => {
        event.preventDefault();
        this.justPressed.add("Space");
      });
      document.querySelectorAll("[data-key]").forEach((button) => {
        const code = button.dataset.key;
        const press = (event) => { event.preventDefault(); this.keys.add(code); };
        const release = (event) => { event.preventDefault(); this.keys.delete(code); };
        button.addEventListener("pointerdown", press);
        button.addEventListener("pointerup", release);
        button.addEventListener("pointercancel", release);
        button.addEventListener("pointerleave", release);
      });
    }

    reset() {
      this.state = "playing";
      this.elapsed = 0;
      this.spawnBudget = 0;
      this.round = 1;
      this.score = 0;
      this.kills = 0;
      this.xp = 0;
      this.xpNeeded = 20;
      this.level = 0;
      this.risk = 1;
      this.lastHitAgo = 99;
      this.orbitPhase = 0;
      this.damageMultiplier = 1;
      this.attackInterval = C.unitInterval;
      this.projectileSpeedMultiplier = 1;
      this.mitosis = false;
      this.mitosisTriggers = 0;
      this.mitosisNextKill = Infinity;
      this.pulseKills = 0;
      this.maxUnits = 2;
      this.rules = [];
      this.formation = "ORBIT";
      this.screenShake = 0;
      this.enemies = [];
      this.projectiles = [];
      this.orbs = [];
      this.effects = [];
      this.formulas = [];
      this.particles = [];
      this.nextEnemyId = 1;
      this.nextUnitId = 1;
      this.player = {
        x: C.W / 2, y: 375, hp: C.maxHp,
        lastX: 0, lastY: -1, invuln: 0,
        blinkLeft: 0, blinkCooldown: 0, blinkAgo: 99, trail: []
      };
      this.units = [];
      this.addUnit(false);
      this.addUnit(false);
      upgradeOverlay.hidden = true;
      pauseOverlay.hidden = true;
      resultOverlay.hidden = true;
      canvas.focus();
    }

    frame(time) {
      const rawDelta = Math.min(0.1, (time - this.lastFrame) / 1000);
      this.lastFrame = time;
      if (this.state === "playing") {
        this.accumulator += rawDelta;
        let steps = 0;
        while (this.accumulator >= 1 / 60 && steps < 6) {
          this.update(1 / 60);
          this.accumulator -= 1 / 60;
          steps++;
        }
      } else {
        this.updateEffects(rawDelta);
      }
      this.draw();
      this.justPressed.clear();
      requestAnimationFrame((nextTime) => this.frame(nextTime));
    }

    update(dt) {
      this.elapsed += dt;
      this.updateRound();
      this.lastHitAgo += dt;
      this.orbitPhase += dt * 0.45;
      this.risk = 1 + (this.round - 1) * 0.25;
      this.updatePlayer(dt);
      this.updateSpawning(dt);
      this.updateEnemies(dt);
      this.updateUnits(dt);
      this.updateProjectiles(dt);
      this.updateOrbs(dt);
      this.updateEffects(dt);
      if (this.elapsed >= C.runDuration) this.endRun(true);
    }

    updatePlayer(dt) {
      const p = this.player;
      p.invuln = Math.max(0, p.invuln - dt);
      p.blinkCooldown = Math.max(0, p.blinkCooldown - dt);
      p.blinkAgo += dt;

      let x = (this.keys.has("KeyD") || this.keys.has("ArrowRight") ? 1 : 0)
        - (this.keys.has("KeyA") || this.keys.has("ArrowLeft") ? 1 : 0);
      let y = (this.keys.has("KeyS") || this.keys.has("ArrowDown") ? 1 : 0)
        - (this.keys.has("KeyW") || this.keys.has("ArrowUp") ? 1 : 0);
      const magnitude = length(x, y);
      if (magnitude > 0) {
        x /= magnitude; y /= magnitude;
        p.lastX = x; p.lastY = y;
      }

      if (this.justPressed.has("Space") && p.blinkCooldown <= 0) {
        p.blinkLeft = C.blinkDuration;
        p.blinkCooldown = C.blinkCooldown;
        p.blinkAgo = 0;
        this.burst(p.x, p.y, C.cyan, 38);
      }

      if (p.blinkLeft > 0) {
        p.trail.unshift({ x: p.x, y: p.y });
        p.trail.length = Math.min(7, p.trail.length);
        const speed = C.blinkDistance / C.blinkDuration;
        p.x += p.lastX * speed * dt;
        p.y += p.lastY * speed * dt;
        p.blinkLeft = Math.max(0, p.blinkLeft - dt);
      } else {
        if (p.trail.length) p.trail.pop();
        p.x += x * C.playerSpeed * dt;
        p.y += y * C.playerSpeed * dt;
      }

      p.x = clamp(p.x, C.arena.x + 18, C.arena.x + C.arena.w - 18);
      p.y = clamp(p.y, C.arena.y + 18, C.arena.y + C.arena.h - 18);
    }

    updateSpawning(dt) {
      if (this.enemies.length >= C.enemyMax) return;
      const rate = C.spawnStart * C.spawnGrowth ** (this.round - 1);
      this.spawnBudget += dt * rate;
      while (this.spawnBudget >= 1 && this.enemies.length < C.enemyMax) {
        this.spawnBudget -= 1;
        this.spawnEnemy();
      }
    }

    updateRound() {
      const maxRounds = Math.ceil(C.runDuration / C.roundDuration);
      const nextRound = Math.min(maxRounds, 1 + Math.floor(this.elapsed / C.roundDuration));
      if (nextRound <= this.round) return;
      this.round = nextRound;
      const multiplier = C.spawnGrowth ** (this.round - 1);
      this.floatFormula(this.player.x, this.player.y - 84, `ROUND ${pad(this.round)}  //  ENEMY RATE ×${multiplier}`, C.yellow);
      this.screenShake = Math.max(this.screenShake, 4);
    }

    spawnEnemy() {
      const side = Math.floor(Math.random() * 4);
      let x, y;
      if (side === 0) { x = C.arena.x + Math.random() * C.arena.w; y = C.arena.y + 8; }
      else if (side === 1) { x = C.arena.x + C.arena.w - 8; y = C.arena.y + Math.random() * C.arena.h; }
      else if (side === 2) { x = C.arena.x + Math.random() * C.arena.w; y = C.arena.y + C.arena.h - 8; }
      else { x = C.arena.x + 8; y = C.arena.y + Math.random() * C.arena.h; }
      const healthScale = 1 + Math.max(0, this.elapsed - 120) / 60 * 0.18;
      this.enemies.push({
        id: this.nextEnemyId++, x, y,
        hp: C.enemyHp * healthScale, maxHp: C.enemyHp * healthScale,
        speed: C.enemySpeed * (1 + this.elapsed / C.runDuration * 0.2),
        contact: 0, hitFlash: 0, phase: Math.random() * Math.PI * 2
      });
    }

    updateEnemies(dt) {
      const p = this.player;
      for (const enemy of this.enemies) {
        enemy.contact = Math.max(0, enemy.contact - dt);
        enemy.hitFlash = Math.max(0, enemy.hitFlash - dt);
        enemy.phase += dt * 3;
        let dx = p.x - enemy.x, dy = p.y - enemy.y;
        const mag = Math.max(0.001, length(dx, dy));
        dx /= mag; dy /= mag;
        const wobble = Math.sin(enemy.phase) * 0.08;
        const vx = dx - dy * wobble, vy = dy + dx * wobble;
        enemy.x += vx * enemy.speed * dt;
        enemy.y += vy * enemy.speed * dt;

        const hitRadius = C.enemyRadius + C.playerRadius;
        if (enemy.contact <= 0 && distanceSq(enemy, p) <= hitRadius * hitRadius) {
          enemy.contact = 0.55;
          if (p.invuln <= 0 && p.blinkLeft <= 0) {
            p.hp--;
            p.invuln = C.iFrame;
            this.lastHitAgo = 0;
            this.screenShake = 7;
            this.burst(p.x, p.y, C.red, 48);
            if (p.hp <= 0) { this.endRun(false); return; }
          }
        }
      }
    }

    updateUnits(dt) {
      const wanted = this.units.length >= 3 ? "DELTA" : "ORBIT";
      if (wanted !== this.formation) {
        this.formation = wanted;
        this.floatFormula(this.player.x, this.player.y - 70, "N≥3  →  DELTA", C.yellow);
      }
      this.units.forEach((unit, index) => {
        const target = this.formationTarget(index);
        const follow = 1 - Math.exp(-C.follow * dt);
        unit.x = lerp(unit.x, target.x, follow);
        unit.y = lerp(unit.y, target.y, follow);
        unit.attack -= dt;
        unit.flash = Math.max(0, unit.flash - dt);
        unit.phase += dt * 2.2;
        if (unit.attack <= 0) {
          const enemy = this.nearestEnemy(unit);
          if (enemy) {
            const dx = enemy.x - unit.x, dy = enemy.y - unit.y;
            const mag = Math.max(0.001, length(dx, dy));
            this.projectiles.push({
              x: unit.x, y: unit.y,
              vx: dx / mag * C.projectileSpeed * this.projectileSpeedMultiplier,
              vy: dy / mag * C.projectileSpeed * this.projectileSpeedMultiplier,
              damage: C.unitDamage * this.damageMultiplier,
              life: 1.25, pierce: this.formation === "DELTA" ? 1 : 0,
              source: unit.id, hits: new Set()
            });
            unit.attack += this.attackInterval;
            unit.flash = 0.09;
          } else unit.attack = 0.08;
        }
      });
    }

    formationTarget(index) {
      if (this.formation === "ORBIT") {
        const angle = this.orbitPhase + Math.PI * 2 * index / Math.max(1, this.units.length);
        return { x: this.player.x + Math.cos(angle) * 60, y: this.player.y + Math.sin(angle) * 60 };
      }
      let row = 0, start = 0;
      while (index >= start + row + 1) { start += row + 1; row++; }
      const col = index - start;
      let rows = 1;
      while (rows * (rows + 1) / 2 < this.units.length) rows++;
      const localX = (col - row * 0.5) * 46;
      const localY = (row - (rows - 1) * 0.5) * 39;
      const angle = Math.atan2(this.player.lastY, this.player.lastX) + Math.PI / 2;
      const cos = Math.cos(angle), sin = Math.sin(angle);
      return { x: this.player.x + localX * cos - localY * sin, y: this.player.y + localX * sin + localY * cos };
    }

    nearestEnemy(from) {
      let best = null, bestDist = C.unitRange ** 2;
      for (const enemy of this.enemies) {
        const dist = distanceSq(from, enemy);
        if (dist < bestDist) { bestDist = dist; best = enemy; }
      }
      return best;
    }

    updateProjectiles(dt) {
      for (const projectile of this.projectiles) {
        projectile.x += projectile.vx * dt;
        projectile.y += projectile.vy * dt;
        projectile.life -= dt;
        const hitRadius = C.projectileRadius + C.enemyRadius;
        for (let i = this.enemies.length - 1; i >= 0; i--) {
          const enemy = this.enemies[i];
          if (projectile.hits.has(enemy.id) || distanceSq(projectile, enemy) > hitRadius ** 2) continue;
          projectile.hits.add(enemy.id);
          enemy.hp -= projectile.damage;
          enemy.hitFlash = 0.07;
          this.burst(projectile.x, projectile.y, C.cyan, 12);
          if (enemy.hp <= 0) this.killEnemy(i, projectile.source);
          if (projectile.pierce > 0) projectile.pierce--;
          else { projectile.life = 0; break; }
        }
      }
      this.projectiles = this.projectiles.filter((p) => p.life > 0
        && p.x > C.arena.x - 80 && p.x < C.arena.x + C.arena.w + 80
        && p.y > C.arena.y - 80 && p.y < C.arena.y + C.arena.h + 80);
    }

    killEnemy(index) {
      const enemy = this.enemies[index];
      this.enemies.splice(index, 1);
      this.kills++;
      this.pulseKills++;
      this.score += Math.round(10 * this.risk * (this.lastHitAgo >= 5 ? 1.25 : 1));
      this.burst(enemy.x, enemy.y, C.red, 27);
      this.shatter(enemy.x, enemy.y, C.red);
      if (this.player.blinkAgo <= 0.4) this.floatFormula(enemy.x, enemy.y - 18, "CLOSE CALL", C.yellow);
      this.orbs.push({ x: enemy.x, y: enemy.y, phase: Math.random() * Math.PI * 2 });
      this.checkMitosis();
    }

    updateOrbs(dt) {
      for (const orb of this.orbs) {
        orb.phase += dt * 5;
        const dx = this.player.x - orb.x, dy = this.player.y - orb.y;
        const dist = length(dx, dy);
        if (dist <= C.orbAttract && dist > 0.001) {
          const strength = lerp(0.35, 1, 1 - dist / C.orbAttract);
          orb.x += dx / dist * C.orbSpeed * strength * dt;
          orb.y += dy / dist * C.orbSpeed * strength * dt;
        }
        if (dist <= C.orbCollect) { orb.collected = true; this.gainXp(1); }
      }
      this.orbs = this.orbs.filter((orb) => !orb.collected);
    }

    gainXp(amount) {
      this.xp += amount;
      if (this.xp >= this.xpNeeded && this.level < 7) {
        this.xp -= this.xpNeeded;
        this.level++;
        this.xpNeeded = 20 + this.level * 10;
        this.showUpgrade();
      }
    }

    upgradePool() {
      const mitosis = {
        id: "mitosis", name: "MITOSIS", formula: "●  →  ●●",
        copy: "PULSE 8킬마다 1기 복제 · 최대 5회", forecast: "예상 변화  +5 UNITS"
      };
      const accelerate = {
        id: "accelerate", name: "ACCELERATE", formula: "INTERVAL × 0.85",
        copy: "모든 PULSE 공격 주기 15% 감소", forecast: `${this.attackInterval.toFixed(2)}s → ${(this.attackInterval * .85).toFixed(2)}s`
      };
      const amplify = {
        id: "amplify", name: "AMPLIFY", formula: "DMG × 1.25",
        copy: "모든 PULSE 피해 25% 증가", forecast: `${(10 * this.damageMultiplier).toFixed(1)} → ${(12.5 * this.damageMultiplier).toFixed(1)} DMG`
      };
      if (this.level === 1 && !this.mitosis) return [mitosis, accelerate, amplify];
      const pool = [accelerate, amplify,
        { id: "binary", name: "BINARY", formula: "N  +  1", copy: "PULSE 1기를 즉시 편대에 추가", forecast: `${this.units.length} → ${Math.min(30, this.units.length + 1)} UNITS` },
        { id: "vectoring", name: "VECTORING", formula: "SPEED × 1.20", copy: "탄환 속도 20% 증가", forecast: "명중까지 걸리는 시간 감소" },
        { id: "repair", name: "REPAIR", formula: "HP  +  1", copy: "CORE 체력을 1 회복", forecast: `${this.player.hp} → ${Math.min(C.maxHp, this.player.hp + 1)} CORE` }
      ];
      if (!this.mitosis) pool.push(mitosis);
      return pool.sort(() => Math.random() - .5).slice(0, 3);
    }

    showUpgrade() {
      this.state = "upgrading";
      this.currentOptions = this.upgradePool();
      upgradeTitle.textContent = `LEVEL ${pad(this.level)} // SELECT NEW FORMULA`;
      upgradeCards.replaceChildren();
      this.currentOptions.forEach((option, index) => {
        const button = document.createElement("button");
        button.className = "formula-card";
        button.innerHTML = `<span class="card-number">[ ${index + 1} ]</span><strong class="card-name">${option.name}</strong><span class="card-formula">${option.formula}</span><span class="card-copy">${option.copy}</span><span class="card-forecast">${option.forecast}</span>`;
        button.addEventListener("click", () => this.chooseUpgrade(option));
        upgradeCards.appendChild(button);
      });
      upgradeOverlay.hidden = false;
      upgradeCards.querySelector("button")?.focus();
    }

    chooseUpgrade(option) {
      if (!option || this.state !== "upgrading") return;
      if (option.id === "mitosis") {
        this.mitosis = true;
        this.mitosisNextKill = this.pulseKills + 8;
        this.rules.push("MITOSIS");
        this.floatFormula(this.player.x, this.player.y - 62, "●  →  ●●", C.cyan);
      } else if (option.id === "accelerate") {
        this.attackInterval *= .85; this.rules.push("×0.85");
        this.floatFormula(this.player.x, this.player.y - 62, "INTERVAL × 0.85", C.cyan);
      } else if (option.id === "amplify") {
        this.damageMultiplier *= 1.25; this.rules.push("DMG×1.25");
        this.floatFormula(this.player.x, this.player.y - 62, "DMG × 1.25", C.cyan);
      } else if (option.id === "binary") {
        this.addUnit(true); this.rules.push("N+1");
      } else if (option.id === "vectoring") {
        this.projectileSpeedMultiplier *= 1.2; this.rules.push("SPEED×1.20");
      } else if (option.id === "repair") {
        this.player.hp = Math.min(C.maxHp, this.player.hp + 1); this.rules.push("HP+1");
      }
      upgradeOverlay.hidden = true;
      this.state = "playing";
      canvas.focus();
    }

    checkMitosis() {
      if (!this.mitosis || this.mitosisTriggers >= 5) return;
      while (this.pulseKills >= this.mitosisNextKill && this.mitosisTriggers < 5) {
        this.mitosisTriggers++;
        this.mitosisNextKill += 8;
        if (this.addUnit(true)) this.floatFormula(this.player.x, this.player.y - 70, "●  →  ●●", C.cyan);
      }
    }

    addUnit(effect) {
      if (this.units.length >= 30) { this.damageMultiplier *= 1.03; return false; }
      this.units.push({
        id: this.nextUnitId++, x: this.player.x + Math.random() * 30 - 15,
        y: this.player.y + Math.random() * 30 - 15,
        attack: .08 + Math.random() * C.unitInterval, flash: 0, phase: Math.random() * Math.PI * 2
      });
      this.maxUnits = Math.max(this.maxUnits, this.units.length);
      if (effect) this.burst(this.player.x, this.player.y, C.cyan, 52);
      return true;
    }

    togglePause() {
      if (this.state === "playing") { this.state = "paused"; pauseOverlay.hidden = false; }
      else if (this.state === "paused") { this.state = "playing"; pauseOverlay.hidden = true; canvas.focus(); }
    }

    endRun(won) {
      if (this.state === "ended") return;
      this.state = "ended";
      const finalScore = this.score + (won ? this.player.hp * 500 : 0);
      this.best = Math.max(this.best, finalScore);
      localStorage.setItem("frctl-swarm-best", String(this.best));
      resultTitle.textContent = won ? "FORMULA VERIFIED" : "FORMULA COLLAPSED";
      resultTitle.style.color = won ? C.cyan : C.red;
      const survived = Math.min(this.elapsed, C.runDuration);
      resultStats.innerHTML = `
        <div>SCORE&nbsp; ${pad(finalScore, 6)} &nbsp;&nbsp;//&nbsp;&nbsp; BEST&nbsp; ${pad(this.best, 6)}</div>
        <div>SURVIVAL&nbsp; ${pad(survived / 60)}:${pad(survived % 60)} &nbsp;&nbsp;//&nbsp;&nbsp; KILLS&nbsp; ${this.kills}</div>
        <div>MAX SWARM&nbsp; ${this.maxUnits} &nbsp;&nbsp;//&nbsp;&nbsp; MITOSIS&nbsp; ${this.mitosisTriggers}</div>
        <div class="result-formula">${this.formula()}</div>`;
      resultOverlay.hidden = false;
      document.getElementById("restart-button").focus();
    }

    formula() {
      const parts = [`${this.units.length} PULSE`, this.formation];
      if (this.mitosis) parts.push("MITOSIS");
      for (const rule of this.rules) if (rule !== "MITOSIS" && !parts.includes(rule)) parts.push(rule);
      return parts.join(" × ");
    }

    burst(x, y, color, size) { this.effects.push({ x, y, color, size, life: .28, max: .28 }); }
    floatFormula(x, y, text, color) { this.formulas.push({ x, y, text, color, life: .75, max: .75 }); }

    shatter(x, y, color) {
      const count = 28 + Math.floor(Math.random() * 11);
      const phase = Math.random() * Math.PI * 2;
      for (let index = 0; index < count; index++) {
        const angle = phase + Math.PI * 2 * index / count + (Math.random() - .5) * .48;
        const boost = index % 5 === 0 ? 1.25 : 1;
        const speed = (95 + Math.random() * 245) * boost;
        const life = .38 + Math.random() * .44;
        this.particles.push({
          x, y, px: x, py: y,
          vx: Math.cos(angle) * speed + (Math.random() - .5) * 34,
          vy: Math.sin(angle) * speed + (Math.random() - .5) * 34,
          color, life, max: life,
          size: 1.5 + Math.random() * 2.7,
          rotation: Math.random() * Math.PI * 2,
          spin: (Math.random() - .5) * 26,
          shape: Math.floor(Math.random() * 3)
        });
      }
      if (this.particles.length > 1200) this.particles.splice(0, this.particles.length - 1200);
      this.screenShake = Math.max(this.screenShake, 2.5);
    }

    updateEffects(dt) {
      this.screenShake = Math.max(0, this.screenShake - dt * 18);
      for (const effect of this.effects) effect.life -= dt;
      for (const formula of this.formulas) { formula.life -= dt; formula.y -= 34 * dt; }
      for (const particle of this.particles) {
        particle.life -= dt;
        particle.px = particle.x; particle.py = particle.y;
        particle.x += particle.vx * dt; particle.y += particle.vy * dt;
        const drag = Math.exp(-2.8 * dt);
        particle.vx *= drag; particle.vy *= drag;
        particle.rotation += particle.spin * dt;
      }
      this.effects = this.effects.filter((effect) => effect.life > 0);
      this.formulas = this.formulas.filter((formula) => formula.life > 0);
      this.particles = this.particles.filter((particle) => particle.life > 0);
    }

    draw() {
      ctx.save();
      if (this.screenShake > 0) ctx.translate((Math.random() - .5) * this.screenShake * 2, (Math.random() - .5) * this.screenShake * 2);
      this.drawBackground();
      this.drawFormation();
      this.drawOrbs();
      this.drawEnemies();
      this.drawProjectiles();
      this.drawUnits();
      this.drawPlayer();
      this.drawEffects();
      this.drawHud();
      ctx.restore();
    }

    drawBackground() {
      ctx.fillStyle = C.bg; ctx.fillRect(0, 0, C.W, C.H);
      const a = C.arena;
      ctx.lineWidth = 1;
      for (let x = a.x; x <= a.x + a.w; x += 40) {
        ctx.strokeStyle = rgba((x - a.x) % 200 === 0 ? C.gridMajor : C.grid, .42);
        ctx.beginPath(); ctx.moveTo(x, a.y); ctx.lineTo(x, a.y + a.h); ctx.stroke();
      }
      for (let y = a.y; y <= a.y + a.h; y += 40) {
        ctx.strokeStyle = rgba((y - a.y) % 200 === 0 ? C.gridMajor : C.grid, .42);
        ctx.beginPath(); ctx.moveTo(a.x, y); ctx.lineTo(a.x + a.w, y); ctx.stroke();
      }
      ctx.strokeStyle = rgba(C.cyanDim, .75); ctx.lineWidth = 2; ctx.strokeRect(a.x, a.y, a.w, a.h);
    }

    drawFormation() {
      ctx.lineWidth = 1;
      ctx.strokeStyle = rgba(C.cyanDim, .14);
      for (const unit of this.units) { ctx.beginPath(); ctx.moveTo(this.player.x, this.player.y); ctx.lineTo(unit.x, unit.y); ctx.stroke(); }
      if (this.formation === "DELTA" && this.units.length >= 3) {
        ctx.strokeStyle = rgba(C.cyan, .38); ctx.lineWidth = 2; ctx.beginPath();
        ctx.moveTo(this.units[0].x, this.units[0].y); ctx.lineTo(this.units[1].x, this.units[1].y);
        ctx.lineTo(this.units[2].x, this.units[2].y); ctx.closePath(); ctx.stroke();
      }
    }

    drawPlayer() {
      const p = this.player;
      p.trail.slice().reverse().forEach((trail, index) => {
        ctx.fillStyle = rgba(C.cyan, (index + 1) / Math.max(1, p.trail.length) * .22);
        ctx.beginPath(); ctx.arc(trail.x, trail.y, C.playerRadius * .75, 0, Math.PI * 2); ctx.fill();
      });
      const flicker = p.invuln > 0 && Math.floor(this.elapsed * 18) % 2 === 0;
      ctx.fillStyle = rgba(C.cyan, .1); ctx.beginPath(); ctx.arc(p.x, p.y, 22, 0, Math.PI * 2); ctx.fill();
      ctx.strokeStyle = C.cyanDim; ctx.lineWidth = 2; ctx.beginPath(); ctx.arc(p.x, p.y, 20, 0, Math.PI * 2); ctx.stroke();
      ctx.fillStyle = flicker ? rgba(C.white, .35) : C.white; ctx.beginPath(); ctx.arc(p.x, p.y, 15, 0, Math.PI * 2); ctx.fill();
      ctx.fillStyle = C.bg; ctx.beginPath(); ctx.arc(p.x, p.y, 5, 0, Math.PI * 2); ctx.fill();
      ctx.strokeStyle = C.cyan; ctx.lineWidth = 3; ctx.beginPath(); ctx.moveTo(p.x, p.y); ctx.lineTo(p.x + p.lastX * 11, p.y + p.lastY * 11); ctx.stroke();
      const charge = 1 - p.blinkCooldown / C.blinkCooldown;
      ctx.strokeStyle = C.cyan; ctx.lineWidth = 3; ctx.beginPath(); ctx.arc(p.x, p.y, 27, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * charge); ctx.stroke();
    }

    drawUnits() {
      for (const unit of this.units) {
        const radius = 9 + Math.sin(unit.phase) * .8 + (unit.flash > 0 ? 2.5 : 0);
        ctx.fillStyle = rgba(C.cyan, .1); ctx.beginPath(); ctx.arc(unit.x, unit.y, radius + 5, 0, Math.PI * 2); ctx.fill();
        ctx.fillStyle = C.cyan; ctx.beginPath(); ctx.arc(unit.x, unit.y, radius, 0, Math.PI * 2); ctx.fill();
        ctx.fillStyle = C.bg; ctx.beginPath(); ctx.arc(unit.x, unit.y, radius - 4, 0, Math.PI * 2); ctx.fill();
        ctx.fillStyle = C.white; ctx.beginPath(); ctx.arc(unit.x, unit.y, 2.4, 0, Math.PI * 2); ctx.fill();
      }
    }

    drawEnemies() {
      for (const enemy of this.enemies) {
        const color = enemy.hitFlash > 0 ? C.white : C.red;
        ctx.fillStyle = rgba(C.red, .18); ctx.strokeStyle = color; ctx.lineWidth = 2.5;
        ctx.beginPath(); ctx.moveTo(enemy.x, enemy.y - 13); ctx.lineTo(enemy.x + 13, enemy.y);
        ctx.lineTo(enemy.x, enemy.y + 13); ctx.lineTo(enemy.x - 13, enemy.y); ctx.closePath(); ctx.fill(); ctx.stroke();
        ctx.fillStyle = color; ctx.beginPath(); ctx.arc(enemy.x, enemy.y, 3, 0, Math.PI * 2); ctx.fill();
        if (enemy.hp < enemy.maxHp) {
          ctx.fillStyle = C.redDim; ctx.fillRect(enemy.x - 13, enemy.y - 20, 26, 3);
          ctx.fillStyle = C.red; ctx.fillRect(enemy.x - 13, enemy.y - 20, 26 * Math.max(0, enemy.hp / enemy.maxHp), 3);
        }
      }
    }

    drawProjectiles() {
      ctx.lineCap = "round";
      for (const p of this.projectiles) {
        const angle = Math.atan2(p.vy, p.vx), cos = Math.cos(angle), sin = Math.sin(angle);
        ctx.strokeStyle = rgba(C.cyan, .25); ctx.lineWidth = 7; ctx.beginPath(); ctx.moveTo(p.x - cos * 12, p.y - sin * 12); ctx.lineTo(p.x + cos * 5, p.y + sin * 5); ctx.stroke();
        ctx.strokeStyle = C.white; ctx.lineWidth = 2.5; ctx.beginPath(); ctx.moveTo(p.x - cos * 8, p.y - sin * 8); ctx.lineTo(p.x + cos * 6, p.y + sin * 6); ctx.stroke();
        ctx.fillStyle = C.cyan; ctx.beginPath(); ctx.arc(p.x + cos * 6, p.y + sin * 6, 4, 0, Math.PI * 2); ctx.fill();
      }
    }

    drawOrbs() {
      for (const orb of this.orbs) {
        const radius = 3.5 + Math.sin(orb.phase) * .7;
        ctx.fillStyle = rgba(C.yellow, .13); ctx.beginPath(); ctx.arc(orb.x, orb.y, radius + 4, 0, Math.PI * 2); ctx.fill();
        ctx.fillStyle = C.yellow; ctx.beginPath(); ctx.arc(orb.x, orb.y, radius, 0, Math.PI * 2); ctx.fill();
      }
    }

    drawEffects() {
      for (const effect of this.effects) {
        const progress = 1 - effect.life / effect.max, radius = lerp(3, effect.size, progress);
        ctx.globalAlpha = (1 - progress) * .75; ctx.strokeStyle = effect.color; ctx.lineWidth = 2;
        ctx.beginPath(); ctx.arc(effect.x, effect.y, radius, 0, Math.PI * 2); ctx.stroke();
      }
      ctx.globalAlpha = 1;

      ctx.save();
      ctx.globalCompositeOperation = "lighter";
      ctx.lineCap = "round";
      for (const particle of this.particles) {
        const alpha = clamp(particle.life / particle.max, 0, 1);
        const speed = length(particle.vx, particle.vy);
        const dx = speed > .01 ? particle.vx / speed : 1;
        const dy = speed > .01 ? particle.vy / speed : 0;
        const trail = clamp(speed * .035, 4, 16);
        ctx.globalAlpha = alpha * .2;
        ctx.strokeStyle = particle.color;
        ctx.lineWidth = particle.size * 3.4;
        ctx.beginPath(); ctx.moveTo(particle.x - dx * trail, particle.y - dy * trail); ctx.lineTo(particle.x, particle.y); ctx.stroke();
        ctx.globalAlpha = alpha * .95;
        ctx.strokeStyle = C.white;
        ctx.lineWidth = Math.max(1, particle.size * .55);
        ctx.beginPath(); ctx.moveTo(particle.x - dx * trail * .72, particle.y - dy * trail * .72); ctx.lineTo(particle.x, particle.y); ctx.stroke();

        if (particle.shape === 1) {
          const size = particle.size * 1.8;
          ctx.beginPath();
          ctx.moveTo(particle.x + Math.cos(particle.rotation) * size, particle.y + Math.sin(particle.rotation) * size);
          ctx.lineTo(particle.x + Math.cos(particle.rotation + 2.25) * size, particle.y + Math.sin(particle.rotation + 2.25) * size);
          ctx.lineTo(particle.x + Math.cos(particle.rotation + 4.5) * size, particle.y + Math.sin(particle.rotation + 4.5) * size);
          ctx.closePath(); ctx.stroke();
        } else if (particle.shape === 2) {
          const size = particle.size * 1.5;
          const ax = Math.cos(particle.rotation) * size, ay = Math.sin(particle.rotation) * size;
          ctx.beginPath(); ctx.moveTo(particle.x - ax, particle.y - ay); ctx.lineTo(particle.x + ax, particle.y + ay);
          ctx.moveTo(particle.x + ay, particle.y - ax); ctx.lineTo(particle.x - ay, particle.y + ax); ctx.stroke();
        }
      }
      ctx.restore();

      ctx.textAlign = "center"; ctx.font = "18px ui-monospace, monospace";
      for (const formula of this.formulas) {
        ctx.globalAlpha = formula.life / formula.max; ctx.fillStyle = formula.color; ctx.fillText(formula.text, formula.x, formula.y);
      }
      ctx.globalAlpha = 1;
    }

    drawHud() {
      ctx.textBaseline = "top"; ctx.font = "19px ui-monospace, monospace"; ctx.fillStyle = this.player.hp <= 1 ? C.red : C.white; ctx.textAlign = "left";
      ctx.fillText(`CORE  ${"◆ ".repeat(this.player.hp)}${"◇ ".repeat(C.maxHp - this.player.hp)}`, 36, 22);
      const remain = Math.max(0, Math.ceil(C.runDuration - this.elapsed));
      ctx.textAlign = "center"; ctx.font = "27px ui-monospace, monospace"; ctx.fillStyle = remain <= 30 ? C.red : C.white;
      ctx.fillText(`${pad(remain / 60)}:${pad(remain % 60)}`, 640, 17);
      ctx.textAlign = "right"; ctx.font = "17px ui-monospace, monospace"; ctx.fillStyle = C.white;
      ctx.fillText(`SCORE  ${pad(this.score, 6)}  //  RISK ×${this.risk.toFixed(2)}`, 1244, 25);
      ctx.textAlign = "left"; ctx.font = "15px ui-monospace, monospace"; ctx.fillStyle = C.cyan;
      ctx.fillText(`FORMATION  //  ${this.formation}${this.formation === "DELTA" ? "  //  PIERCE +1" : ""}`, 42, 92);
      ctx.fillText(`FORMULA  //  ${this.formula()}`, 42, 632);
      ctx.textAlign = "center"; ctx.font = "13px ui-monospace, monospace"; ctx.fillStyle = "#8ca7b3";
      const blink = Math.round((1 - this.player.blinkCooldown / C.blinkCooldown) * 100);
      ctx.fillText(`ROUND ${pad(this.round)}  //  BLINK ${pad(blink, 3)}%  //  AUTO-FIRE ONLINE`, 640, 67);
      if (this.elapsed < 15) {
        ctx.globalAlpha = clamp((15 - this.elapsed) / 4, 0, 1); ctx.font = "16px ui-monospace, monospace"; ctx.fillStyle = C.yellow;
        ctx.fillText("WASD / ARROWS  MOVE     SPACE  BLINK", 640, 574); ctx.globalAlpha = 1;
      }
      ctx.textAlign = "right"; ctx.font = "13px ui-monospace, monospace"; ctx.fillStyle = "#8ca7b3";
      ctx.fillText(`E ${this.enemies.length}  U ${this.units.length}  P ${this.projectiles.length}`, 1230, 636);
      const barX = 350, barY = 686, barW = 580, progress = clamp(this.xp / this.xpNeeded, 0, 1);
      ctx.fillStyle = "#061421"; ctx.fillRect(barX, barY, barW, 12); ctx.fillStyle = C.yellow; ctx.fillRect(barX, barY, barW * progress, 12);
      ctx.textAlign = "center"; ctx.font = "12px ui-monospace, monospace"; ctx.fillStyle = C.white;
      ctx.fillText(`ENERGY ${this.xp} / ${this.xpNeeded}`, 640, 664);
    }
  }

  window.frctlSwarm = new Game();
})();
