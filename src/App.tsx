import { useState, useEffect, useCallback, useRef } from 'react';

type Direction = 'UP' | 'DOWN' | 'LEFT' | 'RIGHT';
type Position = { x: number; y: number };
type Difficulty = 'easy' | 'medium' | 'hard';
type GameState = 'idle' | 'playing' | 'paused' | 'gameover';

const GRID_SIZE = 20;
const SPEEDS: Record<Difficulty, number> = {
  easy: 150,
  medium: 100,
  hard: 60,
};

const DIFFICULTY_LABELS: Record<Difficulty, string> = {
  easy: 'Легкая',
  medium: 'Средняя',
  hard: 'Сложная',
};

function getRandomPosition(snake: Position[]): Position {
  let pos: Position;
  do {
    pos = {
      x: Math.floor(Math.random() * GRID_SIZE),
      y: Math.floor(Math.random() * GRID_SIZE),
    };
  } while (snake.some((s) => s.x === pos.x && s.y === pos.y));
  return pos;
}

export default function App() {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const [gameState, setGameState] = useState<GameState>('idle');
  const [difficulty, setDifficulty] = useState<Difficulty>('medium');
  const [score, setScore] = useState(0);
  const [highScore, setHighScore] = useState(() => {
    const saved = localStorage.getItem('snake-high-score');
    return saved ? parseInt(saved, 10) : 0;
  });
  const [snake, setSnake] = useState<Position[]>([{ x: 10, y: 10 }]);
  const [food, setFood] = useState<Position>({ x: 15, y: 15 });
  const [direction, setDirection] = useState<Direction>('RIGHT');
  const [eatAnimation, setEatAnimation] = useState(false);

  const directionRef = useRef<Direction>('RIGHT');
  const gameStateRef = useRef<GameState>('idle');
  const snakeRef = useRef<Position[]>([{ x: 10, y: 10 }]);
  const foodRef = useRef<Position>({ x: 15, y: 15 });
  const scoreRef = useRef(0);
  const touchStartRef = useRef<{ x: number; y: number } | null>(null);

  useEffect(() => {
    directionRef.current = direction;
  }, [direction]);

  useEffect(() => {
    gameStateRef.current = gameState;
  }, [gameState]);

  useEffect(() => {
    snakeRef.current = snake;
  }, [snake]);

  useEffect(() => {
    foodRef.current = food;
  }, [food]);

  useEffect(() => {
    scoreRef.current = score;
  }, [score]);

  const resetGame = useCallback(() => {
    const initialSnake = [{ x: 10, y: 10 }];
    const initialFood = getRandomPosition(initialSnake);
    setSnake(initialSnake);
    setFood(initialFood);
    setDirection('RIGHT');
    setScore(0);
    directionRef.current = 'RIGHT';
    snakeRef.current = initialSnake;
    foodRef.current = initialFood;
    scoreRef.current = 0;
  }, []);

  const startGame = useCallback(() => {
    resetGame();
    setGameState('playing');
  }, [resetGame]);

  const togglePause = useCallback(() => {
    if (gameStateRef.current === 'playing') {
      setGameState('paused');
    } else if (gameStateRef.current === 'paused') {
      setGameState('playing');
    }
  }, []);

  const changeDirection = useCallback((newDir: Direction) => {
    const current = directionRef.current;
    const opposites: Record<Direction, Direction> = {
      UP: 'DOWN',
      DOWN: 'UP',
      LEFT: 'RIGHT',
      RIGHT: 'LEFT',
    };
    if (opposites[newDir] !== current) {
      setDirection(newDir);
    }
  }, []);

  // Game loop
  useEffect(() => {
    if (gameState !== 'playing') return;

    const interval = setInterval(() => {
      const currentSnake = [...snakeRef.current];
      const head = { ...currentSnake[0] };
      const dir = directionRef.current;

      switch (dir) {
        case 'UP': head.y -= 1; break;
        case 'DOWN': head.y += 1; break;
        case 'LEFT': head.x -= 1; break;
        case 'RIGHT': head.x += 1; break;
      }

      // Check wall collision
      if (head.x < 0 || head.x >= GRID_SIZE || head.y < 0 || head.y >= GRID_SIZE) {
        setGameState('gameover');
        const currentScore = scoreRef.current;
        const savedHigh = parseInt(localStorage.getItem('snake-high-score') || '0', 10);
        if (currentScore > savedHigh) {
          localStorage.setItem('snake-high-score', currentScore.toString());
          setHighScore(currentScore);
        }
        return;
      }

      // Check self collision
      if (currentSnake.some((s) => s.x === head.x && s.y === head.y)) {
        setGameState('gameover');
        const currentScore = scoreRef.current;
        const savedHigh = parseInt(localStorage.getItem('snake-high-score') || '0', 10);
        if (currentScore > savedHigh) {
          localStorage.setItem('snake-high-score', currentScore.toString());
          setHighScore(currentScore);
        }
        return;
      }

      const newSnake = [head, ...currentSnake];
      const currentFood = foodRef.current;

      if (head.x === currentFood.x && head.y === currentFood.y) {
        // Ate food
        const newScore = scoreRef.current + 10;
        setScore(newScore);
        const newFood = getRandomPosition(newSnake);
        setFood(newFood);
        setEatAnimation(true);
        setTimeout(() => setEatAnimation(false), 300);
      } else {
        newSnake.pop();
      }

      setSnake(newSnake);
      snakeRef.current = newSnake;
    }, SPEEDS[difficulty]);

    return () => clearInterval(interval);
  }, [gameState, difficulty]);

  // Keyboard controls
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      switch (e.key) {
        case 'ArrowUp':
        case 'w':
        case 'W':
          e.preventDefault();
          if (gameStateRef.current === 'playing') changeDirection('UP');
          break;
        case 'ArrowDown':
        case 's':
        case 'S':
          e.preventDefault();
          if (gameStateRef.current === 'playing') changeDirection('DOWN');
          break;
        case 'ArrowLeft':
        case 'a':
        case 'A':
          e.preventDefault();
          if (gameStateRef.current === 'playing') changeDirection('LEFT');
          break;
        case 'ArrowRight':
        case 'd':
        case 'D':
          e.preventDefault();
          if (gameStateRef.current === 'playing') changeDirection('RIGHT');
          break;
        case ' ':
          e.preventDefault();
          if (gameStateRef.current === 'idle' || gameStateRef.current === 'gameover') {
            startGame();
          } else {
            togglePause();
          }
          break;
        case 'r':
        case 'R':
          e.preventDefault();
          startGame();
          break;
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [changeDirection, startGame, togglePause]);

  // Touch controls
  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;

    const handleTouchStart = (e: TouchEvent) => {
      const touch = e.touches[0];
      touchStartRef.current = { x: touch.clientX, y: touch.clientY };
    };

    const handleTouchEnd = (e: TouchEvent) => {
      if (!touchStartRef.current) return;
      const touch = e.changedTouches[0];
      const dx = touch.clientX - touchStartRef.current.x;
      const dy = touch.clientY - touchStartRef.current.y;
      const minSwipe = 30;

      if (Math.abs(dx) < minSwipe && Math.abs(dy) < minSwipe) return;

      if (gameStateRef.current !== 'playing') return;

      if (Math.abs(dx) > Math.abs(dy)) {
        changeDirection(dx > 0 ? 'RIGHT' : 'LEFT');
      } else {
        changeDirection(dy > 0 ? 'DOWN' : 'UP');
      }
      touchStartRef.current = null;
    };

    canvas.addEventListener('touchstart', handleTouchStart, { passive: true });
    canvas.addEventListener('touchend', handleTouchEnd, { passive: true });

    return () => {
      canvas.removeEventListener('touchstart', handleTouchStart);
      canvas.removeEventListener('touchend', handleTouchEnd);
    };
  }, [changeDirection]);

  // Canvas rendering
  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;

    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    const cellSize = canvas.width / GRID_SIZE;

    // Clear
    ctx.fillStyle = '#0f172a';
    ctx.fillRect(0, 0, canvas.width, canvas.height);

    // Grid lines
    ctx.strokeStyle = '#1e293b';
    ctx.lineWidth = 0.5;
    for (let i = 0; i <= GRID_SIZE; i++) {
      ctx.beginPath();
      ctx.moveTo(i * cellSize, 0);
      ctx.lineTo(i * cellSize, canvas.height);
      ctx.stroke();
      ctx.beginPath();
      ctx.moveTo(0, i * cellSize);
      ctx.lineTo(canvas.width, i * cellSize);
      ctx.stroke();
    }

    // Snake
    snake.forEach((segment, index) => {
      const isHead = index === 0;
      const progress = 1 - index / snake.length;
      
      if (isHead) {
        ctx.fillStyle = '#22d3ee';
        ctx.shadowColor = '#22d3ee';
        ctx.shadowBlur = 8;
      } else {
        const green = Math.floor(180 + progress * 75);
        ctx.fillStyle = `rgb(16, ${green}, ${Math.floor(100 + progress * 80)})`;
        ctx.shadowColor = '#10b981';
        ctx.shadowBlur = 3;
      }

      const padding = isHead ? 1 : 2;
      const radius = isHead ? 6 : 4;
      const x = segment.x * cellSize + padding;
      const y = segment.y * cellSize + padding;
      const size = cellSize - padding * 2;

      ctx.beginPath();
      ctx.roundRect(x, y, size, size, radius);
      ctx.fill();
      ctx.shadowBlur = 0;

      // Eyes on head
      if (isHead) {
        ctx.fillStyle = '#0f172a';
        const eyeSize = cellSize * 0.15;
        let eye1X: number, eye1Y: number, eye2X: number, eye2Y: number;
        const centerX = segment.x * cellSize + cellSize / 2;
        const centerY = segment.y * cellSize + cellSize / 2;

        switch (direction) {
          case 'RIGHT':
            eye1X = centerX + cellSize * 0.15; eye1Y = centerY - cellSize * 0.2;
            eye2X = centerX + cellSize * 0.15; eye2Y = centerY + cellSize * 0.2;
            break;
          case 'LEFT':
            eye1X = centerX - cellSize * 0.15; eye1Y = centerY - cellSize * 0.2;
            eye2X = centerX - cellSize * 0.15; eye2Y = centerY + cellSize * 0.2;
            break;
          case 'UP':
            eye1X = centerX - cellSize * 0.2; eye1Y = centerY - cellSize * 0.15;
            eye2X = centerX + cellSize * 0.2; eye2Y = centerY - cellSize * 0.15;
            break;
          case 'DOWN':
            eye1X = centerX - cellSize * 0.2; eye1Y = centerY + cellSize * 0.15;
            eye2X = centerX + cellSize * 0.2; eye2Y = centerY + cellSize * 0.15;
            break;
        }
        ctx.beginPath();
        ctx.arc(eye1X, eye1Y, eyeSize, 0, Math.PI * 2);
        ctx.fill();
        ctx.beginPath();
        ctx.arc(eye2X, eye2Y, eyeSize, 0, Math.PI * 2);
        ctx.fill();
      }
    });

    // Food
    ctx.shadowColor = '#f43f5e';
    ctx.shadowBlur = 12;
    ctx.fillStyle = '#f43f5e';
    const foodX = food.x * cellSize + cellSize / 2;
    const foodY = food.y * cellSize + cellSize / 2;
    const foodRadius = cellSize * 0.35 * (eatAnimation ? 1.3 : 1);
    ctx.beginPath();
    ctx.arc(foodX, foodY, foodRadius, 0, Math.PI * 2);
    ctx.fill();
    ctx.shadowBlur = 0;

    // Food inner glow
    ctx.fillStyle = '#fda4af';
    ctx.beginPath();
    ctx.arc(foodX - foodRadius * 0.2, foodY - foodRadius * 0.2, foodRadius * 0.4, 0, Math.PI * 2);
    ctx.fill();

  }, [snake, food, direction, eatAnimation]);

  // Responsive canvas
  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;

    const resizeCanvas = () => {
      const container = canvas.parentElement;
      if (!container) return;
      const size = Math.min(container.clientWidth, container.clientHeight, 500);
      canvas.width = size;
      canvas.height = size;
    };

    resizeCanvas();
    window.addEventListener('resize', resizeCanvas);
    return () => window.removeEventListener('resize', resizeCanvas);
  }, []);

  return (
    <div className="min-h-screen bg-gradient-to-br from-slate-900 via-slate-800 to-slate-900 flex flex-col items-center justify-center p-4 select-none">
      {/* Header */}
      <div className="w-full max-w-lg mb-4">
        <h1 className="text-3xl md:text-4xl font-bold text-center text-transparent bg-clip-text bg-gradient-to-r from-cyan-400 to-emerald-400 mb-2">
          🐍 Змейка
        </h1>

        {/* Score panel */}
        <div className="flex justify-between items-center bg-slate-800/80 backdrop-blur rounded-xl px-4 py-3 border border-slate-700">
          <div className="text-center">
            <div className="text-xs text-slate-400 uppercase tracking-wide">Счёт</div>
            <div className={`text-2xl font-bold text-cyan-400 transition-transform ${eatAnimation ? 'scale-125' : 'scale-100'}`}>
              {score}
            </div>
          </div>
          <div className="text-center">
            <div className="text-xs text-slate-400 uppercase tracking-wide">Сложность</div>
            <div className="text-lg font-semibold text-amber-400">
              {DIFFICULTY_LABELS[difficulty]}
            </div>
          </div>
          <div className="text-center">
            <div className="text-xs text-slate-400 uppercase tracking-wide">Рекорд</div>
            <div className="text-2xl font-bold text-emerald-400">
              {highScore}
            </div>
          </div>
        </div>
      </div>

      {/* Game area */}
      <div className="relative w-full max-w-lg aspect-square">
        <canvas
          ref={canvasRef}
          className="w-full h-full rounded-2xl border-2 border-slate-700 shadow-2xl shadow-cyan-500/10"
        />

        {/* Overlay states */}
        {gameState === 'idle' && (
          <div className="absolute inset-0 flex flex-col items-center justify-center bg-slate-900/85 backdrop-blur-sm rounded-2xl">
            <div className="text-6xl mb-4 animate-bounce">🐍</div>
            <h2 className="text-2xl font-bold text-white mb-2">Готовы играть?</h2>
            <p className="text-slate-400 text-sm mb-6 text-center px-4">
              Используйте стрелки/WASD или свайпы для управления
            </p>
            
            {/* Difficulty selector */}
            <div className="flex gap-2 mb-6">
              {(['easy', 'medium', 'hard'] as Difficulty[]).map((d) => (
                <button
                  key={d}
                  onClick={() => setDifficulty(d)}
                  className={`px-4 py-2 rounded-lg font-medium text-sm transition-all ${
                    difficulty === d
                      ? d === 'easy' ? 'bg-green-500/20 text-green-400 border border-green-500/50'
                        : d === 'medium' ? 'bg-amber-500/20 text-amber-400 border border-amber-500/50'
                        : 'bg-red-500/20 text-red-400 border border-red-500/50'
                      : 'bg-slate-700/50 text-slate-400 border border-slate-600 hover:border-slate-500'
                  }`}
                >
                  {DIFFICULTY_LABELS[d]}
                </button>
              ))}
            </div>

            <button
              onClick={startGame}
              className="px-8 py-3 bg-gradient-to-r from-cyan-500 to-emerald-500 text-white font-bold rounded-xl shadow-lg shadow-cyan-500/25 hover:shadow-cyan-500/40 hover:scale-105 transition-all active:scale-95"
            >
              Начать игру
            </button>
            <p className="text-slate-500 text-xs mt-3">или нажмите Пробел</p>
          </div>
        )}

        {gameState === 'paused' && (
          <div className="absolute inset-0 flex flex-col items-center justify-center bg-slate-900/85 backdrop-blur-sm rounded-2xl">
            <div className="text-5xl mb-4">⏸️</div>
            <h2 className="text-2xl font-bold text-white mb-4">Пауза</h2>
            <button
              onClick={togglePause}
              className="px-8 py-3 bg-gradient-to-r from-cyan-500 to-emerald-500 text-white font-bold rounded-xl shadow-lg hover:scale-105 transition-all active:scale-95"
            >
              Продолжить
            </button>
            <p className="text-slate-500 text-xs mt-3">или нажмите Пробел</p>
          </div>
        )}

        {gameState === 'gameover' && (
          <div className="absolute inset-0 flex flex-col items-center justify-center bg-slate-900/85 backdrop-blur-sm rounded-2xl">
            <div className="text-5xl mb-4">💀</div>
            <h2 className="text-2xl font-bold text-red-400 mb-2">Игра окончена!</h2>
            <p className="text-4xl font-bold text-white mb-1">{score}</p>
            <p className="text-slate-400 text-sm mb-2">очков набрано</p>
            {score >= highScore && score > 0 && (
              <p className="text-amber-400 font-semibold mb-4 animate-pulse">🏆 Новый рекорд!</p>
            )}
            
            <div className="flex gap-2 mb-4">
              {(['easy', 'medium', 'hard'] as Difficulty[]).map((d) => (
                <button
                  key={d}
                  onClick={() => setDifficulty(d)}
                  className={`px-3 py-1.5 rounded-lg font-medium text-xs transition-all ${
                    difficulty === d
                      ? d === 'easy' ? 'bg-green-500/20 text-green-400 border border-green-500/50'
                        : d === 'medium' ? 'bg-amber-500/20 text-amber-400 border border-amber-500/50'
                        : 'bg-red-500/20 text-red-400 border border-red-500/50'
                      : 'bg-slate-700/50 text-slate-400 border border-slate-600'
                  }`}
                >
                  {DIFFICULTY_LABELS[d]}
                </button>
              ))}
            </div>

            <button
              onClick={startGame}
              className="px-8 py-3 bg-gradient-to-r from-cyan-500 to-emerald-500 text-white font-bold rounded-xl shadow-lg hover:scale-105 transition-all active:scale-95"
            >
              Играть снова
            </button>
            <p className="text-slate-500 text-xs mt-3">или нажмите Пробел / R</p>
          </div>
        )}
      </div>

      {/* Controls */}
      <div className="w-full max-w-lg mt-4">
        {/* Action buttons */}
        <div className="flex justify-center gap-3 mb-4">
          {gameState === 'playing' && (
            <button
              onClick={togglePause}
              className="px-5 py-2 bg-slate-700/80 text-slate-300 rounded-lg border border-slate-600 hover:bg-slate-600/80 transition-all active:scale-95 text-sm font-medium"
            >
              ⏸ Пауза
            </button>
          )}
          {(gameState === 'playing' || gameState === 'paused') && (
            <button
              onClick={startGame}
              className="px-5 py-2 bg-slate-700/80 text-slate-300 rounded-lg border border-slate-600 hover:bg-slate-600/80 transition-all active:scale-95 text-sm font-medium"
            >
              🔄 Заново
            </button>
          )}
        </div>

        {/* Mobile D-pad */}
        <div className="md:hidden grid grid-cols-3 gap-2 max-w-[200px] mx-auto">
          <div></div>
          <button
            onTouchStart={(e) => { e.preventDefault(); if (gameState === 'playing') changeDirection('UP'); }}
            className="w-14 h-14 bg-slate-700/80 rounded-xl flex items-center justify-center text-2xl text-slate-300 active:bg-slate-600 border border-slate-600 active:scale-90 transition-all"
          >
            ▲
          </button>
          <div></div>
          <button
            onTouchStart={(e) => { e.preventDefault(); if (gameState === 'playing') changeDirection('LEFT'); }}
            className="w-14 h-14 bg-slate-700/80 rounded-xl flex items-center justify-center text-2xl text-slate-300 active:bg-slate-600 border border-slate-600 active:scale-90 transition-all"
          >
            ◀
          </button>
          <button
            onTouchStart={(e) => { e.preventDefault(); if (gameState === 'playing') changeDirection('DOWN'); }}
            className="w-14 h-14 bg-slate-700/80 rounded-xl flex items-center justify-center text-2xl text-slate-300 active:bg-slate-600 border border-slate-600 active:scale-90 transition-all"
          >
            ▼
          </button>
          <button
            onTouchStart={(e) => { e.preventDefault(); if (gameState === 'playing') changeDirection('RIGHT'); }}
            className="w-14 h-14 bg-slate-700/80 rounded-xl flex items-center justify-center text-2xl text-slate-300 active:bg-slate-600 border border-slate-600 active:scale-90 transition-all"
          >
            ▶
          </button>
        </div>

        {/* Desktop controls hint */}
        <div className="hidden md:flex justify-center gap-4 text-slate-500 text-xs mt-2">
          <span>← → ↑ ↓ / WASD — управление</span>
          <span>Пробел — пауза</span>
          <span>R — перезапуск</span>
        </div>
      </div>
    </div>
  );
}
