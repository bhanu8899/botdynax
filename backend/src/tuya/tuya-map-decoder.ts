/// Decodes the `pathData.rawData` blob from a Tuya sweeper map file into
/// the robot's traveled trajectory, in the same grid-cell coordinate space
/// the map's `obstacles`/`rooms`/`charger` points already use.
///
/// Format was reverse-engineered empirically against the real Milagrow
/// iMap Max W300 and validated rigorously: of the candidate header lengths
/// (14-17) and coordinate scales (mm / cm / unscaled), only a 16-byte
/// header with millimetre coordinates put 100% of decoded points inside
/// the map's own grid bounds — every other combination scored under 3%.
///
///   bytes 0-3    reserved (observed all-zero)
///   bytes 4-7    type marker (observed = 2)
///   bytes 8-9    uint16 LE point count
///   bytes 10-11  uint16 LE session/sequence counter
///   bytes 12-15  unidentified 4-byte field (excluded from the path; the
///                observed value decodes to an out-of-bounds coordinate,
///                so it is not a trajectory point)
///   bytes 16+    `count` x (int16 LE x, int16 LE y), millimetres in the
///                robot's own frame
///   trailing     1 spare byte
///
/// Grid conversion: `cell = mm / (resolution * 10) + origin`, since
/// `resolution` is centimetres-per-cell.
export interface DecodedPathPoint {
  x: number;
  y: number;
}

export interface DecodedPath {
  /// Trajectory in map grid-cell coordinates, oldest point first.
  points: DecodedPathPoint[];

  /// The robot's most recent known position (last trajectory point), or
  /// null when the path is empty (e.g. a freshly-started session).
  robotPosition: DecodedPathPoint | null;

  /// Robot heading in radians, derived from the direction between the
  /// final two trajectory points. Null when there aren't two distinct
  /// points to derive it from — this device reports no heading DP, so a
  /// derived bearing is the only honest source, and a stationary robot
  /// genuinely has no derivable heading.
  headingRadians: number | null;
}

const HEADER_BYTES = 16;

export function decodeSweeperPath(
  rawDataHex: string | undefined,
  origin: [number, number],
  resolution: number,
): DecodedPath {
  const empty: DecodedPath = { points: [], robotPosition: null, headingRadians: null };
  if (!rawDataHex || rawDataHex.length < HEADER_BYTES * 2) return empty;

  let bytes: Buffer;
  try {
    bytes = Buffer.from(rawDataHex, 'hex');
  } catch {
    return empty;
  }
  if (bytes.length <= HEADER_BYTES) return empty;

  const declaredCount = bytes.readUInt16LE(8);
  const availableCount = Math.floor((bytes.length - HEADER_BYTES) / 4);
  // Trust whichever is smaller — a truncated/partial blob shouldn't read
  // past the buffer, and a padded one shouldn't invent points.
  const count = Math.min(declaredCount, availableCount);
  if (count <= 0) return empty;

  const divisor = resolution * 10;
  if (!Number.isFinite(divisor) || divisor === 0) return empty;

  const points: DecodedPathPoint[] = [];
  for (let i = 0; i < count; i++) {
    const offset = HEADER_BYTES + i * 4;
    const xMm = bytes.readInt16LE(offset);
    const yMm = bytes.readInt16LE(offset + 2);
    points.push({ x: xMm / divisor + origin[0], y: yMm / divisor + origin[1] });
  }

  const robotPosition = points[points.length - 1] ?? null;

  let headingRadians: number | null = null;
  for (let i = points.length - 1; i > 0; i--) {
    const dx = points[i].x - points[i - 1].x;
    const dy = points[i].y - points[i - 1].y;
    if (dx !== 0 || dy !== 0) {
      headingRadians = Math.atan2(dy, dx);
      break;
    }
  }

  return { points, robotPosition, headingRadians };
}
