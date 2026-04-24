const GRID_COLS = 25;
const GRID_ROWS = 15;
const TILE_SIZE = 8;
const ROOM_WIDTH = GRID_COLS * TILE_SIZE;
const ROOM_HEIGHT = GRID_ROWS * TILE_SIZE;

const state = {
  jsonFileName: "",
  json: null,
  pngImage: null,
  roomList: [],
  currentRoomListIndex: 0,
  tileCanvasCache: new Map(),
  hashToTileId: new Map(),
  exportReady: false,
  importedTileIds: []
};

const ui = {
  jsonFile: document.getElementById("jsonFile"),
  pngFile: document.getElementById("pngFile"),
  threshold: document.getElementById("threshold"),
  importBtn: document.getElementById("importBtn"),
  exportBtn: document.getElementById("exportBtn"),
  status: document.getElementById("status"),
  prevRoomBtn: document.getElementById("prevRoomBtn"),
  nextRoomBtn: document.getElementById("nextRoomBtn"),
  roomMeta: document.getElementById("roomMeta"),
  roomCanvas: document.getElementById("roomCanvas"),
  tilesCanvas: document.getElementById("tilesCanvas")
};

const roomCtx = ui.roomCanvas.getContext("2d", { alpha: false });
const tilesCtx = ui.tilesCanvas.getContext("2d", { alpha: false });

function setStatus(message, append = false) {
  if (append) {
    ui.status.textContent = `${ui.status.textContent}\n${message}`;
  } else {
    ui.status.textContent = message;
  }
}

function updateButtons() {
  const hasJson = !!state.json;
  const hasPng = !!state.pngImage;
  ui.importBtn.disabled = !(hasJson && hasPng);
  ui.exportBtn.disabled = !state.exportReady;
  ui.prevRoomBtn.disabled = state.roomList.length <= 1;
  ui.nextRoomBtn.disabled = state.roomList.length <= 1;
}

function validatePulpJsonStructure(data) {
  if (!data || typeof data !== "object") {
    return "JSON muss ein Objekt sein.";
  }
  if (!Array.isArray(data.rooms)) {
    return "Feld rooms fehlt oder ist kein Array.";
  }
  if (!Array.isArray(data.tiles)) {
    return "Feld tiles fehlt oder ist kein Array.";
  }
  if (!Array.isArray(data.frames)) {
    return "Feld frames fehlt oder ist kein Array.";
  }
  return null;
}

function getObjectEntriesById(list) {
  return list
    .filter((entry) => entry && typeof entry === "object" && typeof entry.id === "number")
    .sort((a, b) => a.id - b.id);
}

function rebuildRoomList() {
  state.roomList = state.json ? getObjectEntriesById(state.json.rooms) : [];
  if (state.currentRoomListIndex >= state.roomList.length) {
    state.currentRoomListIndex = Math.max(0, state.roomList.length - 1);
  }
}

function getMapById(entries) {
  const map = new Map();
  for (const entry of getObjectEntriesById(entries)) {
    map.set(entry.id, entry);
  }
  return map;
}

function normalizeFrameData(frameData) {
  if (Array.isArray(frameData)) {
    return frameData;
  }
  if (frameData && Array.isArray(frameData.pixels)) {
    return frameData.pixels;
  }
  return null;
}

function createTileCanvasFromFrame(frameData) {
  const pixels = normalizeFrameData(frameData);
  const tileCanvas = document.createElement("canvas");
  tileCanvas.width = TILE_SIZE;
  tileCanvas.height = TILE_SIZE;
  const ctx = tileCanvas.getContext("2d", { alpha: false });
  const imageData = ctx.createImageData(TILE_SIZE, TILE_SIZE);

  for (let i = 0; i < TILE_SIZE * TILE_SIZE; i += 1) {
    const value = pixels && typeof pixels[i] === "number" ? pixels[i] : 0;
    const v = value === 1 ? 0 : 255;
    const p = i * 4;
    imageData.data[p] = v;
    imageData.data[p + 1] = v;
    imageData.data[p + 2] = v;
    imageData.data[p + 3] = 255;
  }

  ctx.putImageData(imageData, 0, 0);
  return tileCanvas;
}

function getTileCanvas(tileId, tileById, frameById) {
  if (state.tileCanvasCache.has(tileId)) {
    return state.tileCanvasCache.get(tileId);
  }

  const tile = tileById.get(tileId);
  if (!tile || !Array.isArray(tile.frames) || typeof tile.frames[0] !== "number") {
    return null;
  }

  const frame = frameById.get(tile.frames[0]);
  if (!frame) {
    return null;
  }

  const tileCanvas = createTileCanvasFromFrame(frame.data);
  state.tileCanvasCache.set(tileId, tileCanvas);
  return tileCanvas;
}

function drawMissingTile(ctx, x, y, size) {
  ctx.fillStyle = "#fff";
  ctx.fillRect(x, y, size, size);
  ctx.strokeStyle = "#000";
  ctx.strokeRect(x + 0.5, y + 0.5, size - 1, size - 1);
  ctx.beginPath();
  ctx.moveTo(x + 1, y + 1);
  ctx.lineTo(x + size - 1, y + size - 1);
  ctx.moveTo(x + size - 1, y + 1);
  ctx.lineTo(x + 1, y + size - 1);
  ctx.stroke();
}

function renderCurrentRoom() {
  roomCtx.fillStyle = "#000";
  roomCtx.fillRect(0, 0, ROOM_WIDTH, ROOM_HEIGHT);

  if (!state.json || state.roomList.length === 0) {
    ui.roomMeta.textContent = "Kein Room geladen";
    return;
  }

  const room = state.roomList[state.currentRoomListIndex];
  const tileById = getMapById(state.json.tiles);
  const frameById = getMapById(state.json.frames);

  const roomName = room.name || "(ohne Name)";
  ui.roomMeta.textContent = `Room ${state.currentRoomListIndex + 1}/${state.roomList.length} | id=${room.id} | ${roomName}`;

  const roomTiles = Array.isArray(room.tiles) ? room.tiles : [];
  for (let row = 0; row < GRID_ROWS; row += 1) {
    for (let col = 0; col < GRID_COLS; col += 1) {
      const i = row * GRID_COLS + col;
      const tileId = roomTiles[i];
      const x = col * TILE_SIZE;
      const y = row * TILE_SIZE;

      if (typeof tileId !== "number") {
        drawMissingTile(roomCtx, x, y, TILE_SIZE);
        continue;
      }

      const tileCanvas = getTileCanvas(tileId, tileById, frameById);
      if (!tileCanvas) {
        drawMissingTile(roomCtx, x, y, TILE_SIZE);
      } else {
        roomCtx.drawImage(tileCanvas, x, y);
      }
    }
  }
}

function renderSortedTiles() {
  tilesCtx.fillStyle = "#101010";
  tilesCtx.fillRect(0, 0, ui.tilesCanvas.width, ui.tilesCanvas.height);

  if (!state.json) {
    return;
  }

  const tileById = getMapById(state.json.tiles);
  const frameById = getMapById(state.json.frames);

  const sorted = state.json.editor && Array.isArray(state.json.editor.sortedTiles)
    ? state.json.editor.sortedTiles
    : [];

  const groups = sorted.length > 0 ? sorted : [getObjectEntriesById(state.json.tiles).map((t) => t.id)];

  const tileScale = 2;
  const drawSize = TILE_SIZE * tileScale;
  const cols = 9;
  let yCursor = 10;

  tilesCtx.font = "12px 'Courier New', monospace";
  tilesCtx.textBaseline = "top";

  for (let g = 0; g < groups.length; g += 1) {
    const group = Array.isArray(groups[g]) ? groups[g] : [];

    tilesCtx.fillStyle = "#f5f5f5";
    tilesCtx.fillText(`Gruppe ${g}: ${group.length} Tiles`, 10, yCursor);
    yCursor += 16;

    for (let i = 0; i < group.length; i += 1) {
      const tileId = group[i];
      const col = i % cols;
      const row = Math.floor(i / cols);
      const x = 10 + col * (drawSize + 24);
      const y = yCursor + row * (drawSize + 14);

      const tileCanvas = getTileCanvas(tileId, tileById, frameById);
      if (tileCanvas) {
        tilesCtx.drawImage(tileCanvas, x, y, drawSize, drawSize);
      } else {
        drawMissingTile(tilesCtx, x, y, drawSize);
      }

      tilesCtx.fillStyle = "#c7c7c7";
      tilesCtx.fillText(String(tileId), x, y + drawSize + 1);
    }

    yCursor += Math.ceil(group.length / cols) * (drawSize + 14) + 14;
  }

  if (yCursor + 10 > ui.tilesCanvas.height) {
    const newHeight = yCursor + 10;
    ui.tilesCanvas.height = newHeight;
    renderSortedTiles();
  }
}

function rerenderAll() {
  renderCurrentRoom();
  renderSortedTiles();
  updateButtons();
}

function getNextIdFromArray(array) {
  let maxId = -1;
  for (const entry of array) {
    if (entry && typeof entry === "object" && typeof entry.id === "number" && entry.id > maxId) {
      maxId = entry.id;
    }
  }
  return maxId + 1;
}

function fnv1aHash01(values64) {
  let hash = 0x811c9dc5;
  for (let i = 0; i < values64.length; i += 1) {
    hash ^= values64[i] & 0xff;
    hash = Math.imul(hash, 0x01000193);
  }
  return (hash >>> 0).toString(16).padStart(8, "0");
}

function tileBitsFromImageData(imageData, tileX, tileY, threshold) {
  const bits = new Array(64);
  let p = 0;

  for (let y = 0; y < TILE_SIZE; y += 1) {
    for (let x = 0; x < TILE_SIZE; x += 1) {
      const px = tileX * TILE_SIZE + x;
      const py = tileY * TILE_SIZE + y;
      const idx = (py * ROOM_WIDTH + px) * 4;
      const r = imageData.data[idx];
      const g = imageData.data[idx + 1];
      const b = imageData.data[idx + 2];
      const a = imageData.data[idx + 3];

      const luma = 0.2126 * r + 0.7152 * g + 0.0722 * b;
      const effective = a < 16 ? 0 : luma;
      bits[p] = effective < threshold ? 1 : 0;
      p += 1;
    }
  }

  return bits;
}

function buildHashCacheFromJson() {
  state.hashToTileId.clear();
  const tileById = getMapById(state.json.tiles);
  const frameById = getMapById(state.json.frames);

  for (const tile of tileById.values()) {
    if (!Array.isArray(tile.frames) || typeof tile.frames[0] !== "number") {
      continue;
    }
    const frame = frameById.get(tile.frames[0]);
    if (!frame) {
      continue;
    }
    const pixels = normalizeFrameData(frame.data);
    if (!pixels || pixels.length < 64) {
      continue;
    }
    const hash = fnv1aHash01(pixels.slice(0, 64).map((v) => (v === 1 ? 1 : 0)));
    if (!state.hashToTileId.has(hash)) {
      state.hashToTileId.set(hash, tile.id);
    }
  }
}

function ensureEditorSortedTiles() {
  if (!state.json.editor || typeof state.json.editor !== "object") {
    state.json.editor = {};
  }
  if (!Array.isArray(state.json.editor.sortedTiles)) {
    state.json.editor.sortedTiles = [[]];
  }
  if (!Array.isArray(state.json.editor.sortedTiles[0])) {
    state.json.editor.sortedTiles[0] = [];
  }
  if (!Array.isArray(state.json.editor.sortedTiles[4])) {
    state.json.editor.sortedTiles[4] = [];
  }
}

function appendUnique(targetArray, values) {
  const set = new Set(targetArray);
  for (const v of values) {
    if (!set.has(v)) {
      targetArray.push(v);
      set.add(v);
    }
  }
}

function guessTileDefaults() {
  const fallback = {
    fps: 1,
    type: 0,
    btype: -1,
    solid: false
  };
  const firstTile = getObjectEntriesById(state.json.tiles)[0];
  if (!firstTile) {
    return fallback;
  }
  return {
    fps: typeof firstTile.fps === "number" ? firstTile.fps : fallback.fps,
    type: typeof firstTile.type === "number" ? firstTile.type : fallback.type,
    btype: typeof firstTile.btype === "number" ? firstTile.btype : fallback.btype,
    solid: typeof firstTile.solid === "boolean" ? firstTile.solid : fallback.solid
  };
}

function makeNormalizedImageData(sourceImage) {
  const canvas = document.createElement("canvas");
  canvas.width = ROOM_WIDTH;
  canvas.height = ROOM_HEIGHT;
  const ctx = canvas.getContext("2d", { alpha: false });

  ctx.fillStyle = "#000";
  ctx.fillRect(0, 0, ROOM_WIDTH, ROOM_HEIGHT);

  const scale = Math.min(ROOM_WIDTH / sourceImage.width, ROOM_HEIGHT / sourceImage.height);
  const drawW = Math.round(sourceImage.width * scale);
  const drawH = Math.round(sourceImage.height * scale);
  const offsetX = Math.floor((ROOM_WIDTH - drawW) / 2);
  const offsetY = Math.floor((ROOM_HEIGHT - drawH) / 2);

  ctx.drawImage(sourceImage, offsetX, offsetY, drawW, drawH);

  return {
    imageData: ctx.getImageData(0, 0, ROOM_WIDTH, ROOM_HEIGHT),
    meta: { sourceW: sourceImage.width, sourceH: sourceImage.height, drawW, drawH, offsetX, offsetY }
  };
}

function getDefaultRoomFields() {
  const firstRoom = getObjectEntriesById(state.json.rooms)[0];
  return {
    song: firstRoom && typeof firstRoom.song === "number" ? firstRoom.song : -1,
    script: firstRoom && typeof firstRoom.script === "number" ? firstRoom.script : 0
  };
}

function importPngAsRoom() {
  if (!state.json || !state.pngImage) {
    return;
  }

  const threshold = Number(ui.threshold.value);
  if (!Number.isFinite(threshold) || threshold < 0 || threshold > 255) {
    setStatus("Threshold muss zwischen 0 und 255 liegen.");
    return;
  }

  buildHashCacheFromJson();
  const tileDefaults = guessTileDefaults();
  const roomDefaults = getDefaultRoomFields();
  const { imageData, meta } = makeNormalizedImageData(state.pngImage);

  let nextTileId = getNextIdFromArray(state.json.tiles);
  let nextFrameId = getNextIdFromArray(state.json.frames);
  const nextRoomId = getNextIdFromArray(state.json.rooms);

  const newRoomTiles = new Array(GRID_COLS * GRID_ROWS);
  const newTileIds = [];

  for (let row = 0; row < GRID_ROWS; row += 1) {
    for (let col = 0; col < GRID_COLS; col += 1) {
      const bits = tileBitsFromImageData(imageData, col, row, threshold);
      const hash = fnv1aHash01(bits);
      let tileId = state.hashToTileId.get(hash);

      if (typeof tileId !== "number") {
        const frameId = nextFrameId;
        nextFrameId += 1;

        const newFrame = {
          id: frameId,
          data: bits
        };

        tileId = nextTileId;
        nextTileId += 1;

        const newTile = {
          id: tileId,
          fps: tileDefaults.fps,
          name: `tile_${tileId}`,
          type: tileDefaults.type,
          btype: tileDefaults.btype,
          solid: tileDefaults.solid,
          frames: [frameId]
        };

        state.json.frames.push(newFrame);
        state.json.tiles.push(newTile);
        state.hashToTileId.set(hash, tileId);
        newTileIds.push(tileId);
      }

      newRoomTiles[row * GRID_COLS + col] = tileId;
    }
  }

  const timestamp = new Date().toISOString().replace(/[:.]/g, "-");
  const newRoom = {
    id: nextRoomId,
    name: `import_${timestamp}`,
    song: roomDefaults.song,
    exits: [],
    tiles: newRoomTiles,
    script: roomDefaults.script
  };

  state.json.rooms.push(newRoom);

  ensureEditorSortedTiles();
  appendUnique(state.json.editor.sortedTiles[4], newTileIds);

  state.importedTileIds = newTileIds;
  state.tileCanvasCache.clear();
  state.exportReady = true;

  rebuildRoomList();
  const roomIndex = state.roomList.findIndex((r) => r.id === nextRoomId);
  state.currentRoomListIndex = roomIndex >= 0 ? roomIndex : state.roomList.length - 1;

  rerenderAll();
  setStatus(
    [
      "Import abgeschlossen.",
      `Quelle: ${meta.sourceW}x${meta.sourceH}`,
      `Zielbild: ${ROOM_WIDTH}x${ROOM_HEIGHT} | draw=${meta.drawW}x${meta.drawH} | offset=${meta.offsetX},${meta.offsetY}`,
      `Neuer Room: id=${nextRoomId}`,
      `Neue Tiles: ${newTileIds.length}`,
      `Total Rooms: ${state.roomList.length}`
    ].join("\n")
  );
}

function exportJson() {
  if (!state.json || !state.exportReady) {
    return;
  }

  const jsonText = JSON.stringify(state.json, null, 2);
  const blob = new Blob([jsonText], { type: "application/json" });
  const url = URL.createObjectURL(blob);

  const baseName = state.jsonFileName ? state.jsonFileName.replace(/\.json$/i, "") : "pulp";
  const fileName = `${baseName}_imported.json`;

  const a = document.createElement("a");
  a.href = url;
  a.download = fileName;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);

  setStatus(`Export erstellt: ${fileName}`);
}

async function readTextFile(file) {
  return file.text();
}

async function readPngAsImage(file) {
  const objectUrl = URL.createObjectURL(file);
  try {
    const image = new Image();
    await new Promise((resolve, reject) => {
      image.onload = resolve;
      image.onerror = reject;
      image.src = objectUrl;
    });
    return image;
  } finally {
    URL.revokeObjectURL(objectUrl);
  }
}

ui.jsonFile.addEventListener("change", async (event) => {
  const file = event.target.files && event.target.files[0];
  if (!file) {
    return;
  }

  try {
    const text = await readTextFile(file);
    const parsed = JSON.parse(text);
    const error = validatePulpJsonStructure(parsed);
    if (error) {
      setStatus(`JSON ungueltig: ${error}`);
      state.json = null;
      state.exportReady = false;
      state.roomList = [];
      rerenderAll();
      return;
    }

    state.json = parsed;
    state.jsonFileName = file.name;
    state.currentRoomListIndex = 0;
    state.exportReady = false;
    state.tileCanvasCache.clear();

    rebuildRoomList();
    rerenderAll();
    setStatus(`JSON geladen: ${file.name}\nRooms: ${state.roomList.length}\nTiles: ${getObjectEntriesById(state.json.tiles).length}\nFrames: ${getObjectEntriesById(state.json.frames).length}`);
  } catch (error) {
    setStatus(`Fehler beim Laden der JSON: ${error.message}`);
  }
});

ui.pngFile.addEventListener("change", async (event) => {
  const file = event.target.files && event.target.files[0];
  if (!file) {
    return;
  }

  try {
    const image = await readPngAsImage(file);
    state.pngImage = image;
    setStatus(`PNG geladen: ${file.name}\nAufloesung: ${image.width}x${image.height}`);
    updateButtons();
  } catch (error) {
    state.pngImage = null;
    setStatus(`Fehler beim Laden des PNG: ${error.message}`);
    updateButtons();
  }
});

ui.prevRoomBtn.addEventListener("click", () => {
  if (state.roomList.length === 0) {
    return;
  }
  state.currentRoomListIndex = (state.currentRoomListIndex - 1 + state.roomList.length) % state.roomList.length;
  renderCurrentRoom();
});

ui.nextRoomBtn.addEventListener("click", () => {
  if (state.roomList.length === 0) {
    return;
  }
  state.currentRoomListIndex = (state.currentRoomListIndex + 1) % state.roomList.length;
  renderCurrentRoom();
});

ui.importBtn.addEventListener("click", () => {
  try {
    importPngAsRoom();
  } catch (error) {
    setStatus(`Import fehlgeschlagen: ${error.message}`);
  }
});

ui.exportBtn.addEventListener("click", () => {
  try {
    exportJson();
  } catch (error) {
    setStatus(`Export fehlgeschlagen: ${error.message}`);
  }
});

setStatus("Bereit. Bitte JSON und PNG waehlen.");
rerenderAll();
