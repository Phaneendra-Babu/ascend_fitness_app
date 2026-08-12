"""
Muscle group extraction v3 — component-based with region filtering.
1. Dilate walls to close anti-aliasing gaps
2. Compute all connected components
3. Map seed points → components → muscle groups
4. Apply region filtering for muscles that share components (obliques)
5. Export each group as transparent PNG
"""
from PIL import Image
from collections import deque
import json
import os

INPUT = 'front_body_base.png'
OUTDIR = 'muscles_front'
WALL_LUM = 130       # raised from 120 to catch anti-aliased edges
ALPHA_WALL = 200     # transparent = wall
DILATE_RADIUS = 1    # dilate walls by 1px to close gaps

# --- Component seed points: each seed maps to ONE connected component ---
SEEDS = {
    # Chest
    'left_pec':       [(310, 300)],
    'right_pec':      [(400, 300)],
    # Shoulders (anterior delt)
    'left_delt':      [(228, 289)],
    'right_delt':     [(485, 300)],
    # Biceps — single seed per arm to avoid oblique contamination
    'left_bicep':     [(196, 383)],
    'right_bicep':    [(509, 383)],
    # Forearms — seeds well above the wrist line
    'left_forearm':   [(129, 482), (100, 620)],
    'right_forearm':  [(577, 482), (600, 620)],
    # Abs — seeds inside each ab block (3 rows of 2 = six-pack)
    'ab_block_1L':    [(325, 391)],
    'ab_block_1R':    [(380, 391)],
    'ab_block_2L':    [(325, 435)],
    'ab_block_2R':    [(380, 435)],
    'ab_block_3L':    [(325, 475)],
    'ab_block_3R':    [(380, 475)],
    # Obliques — side torso (left and right of abs)
    # These seeds hit the torso background component; region filtering
    # is applied later to keep only the oblique area.
    'left_oblique':   [(260, 460), (260, 540), (245, 500)],
    'right_oblique':  [(450, 460), (450, 540), (425, 500)],
    # Lower core / inguinal strip between abs and quads
    # Removed from component extraction — handled via image-based post-processing
    # Quads — multiple seeds per leg
    'left_quad_main': [(261, 700)],
    'left_quad_inner': [(296, 767)],
    'left_quad_mid':  [(300, 653)],
    'right_quad_main': [(444, 700)],
    'right_quad_inner': [(409, 767)],
    'right_quad_mid': [(406, 653)],
    # Calves
    'left_calf_outer': [(220, 950)],
    'left_calf_inner': [(285, 958)],
    'left_calf_upper': [(263, 868)],
    'right_calf_outer': [(495, 1000)],
    'right_calf_inner': [(420, 957)],
    'right_calf_upper': [(442, 869)],
    # Traps / neck
    'traps_upper':    [(350, 200)],
    'traps_mid':      [(350, 230)],
}

# Mapping: muscle group → list of component seed keys to merge
MUSCLE_GROUPS = {
    'chest':      ['left_pec', 'right_pec'],
    'shoulders':  ['left_delt', 'right_delt'],
    'biceps':     ['left_bicep', 'right_bicep'],
    'forearms':   ['left_forearm', 'right_forearm'],
    'abs':        ['ab_block_1L', 'ab_block_1R', 'ab_block_2L', 'ab_block_2R',
                   'ab_block_3L', 'ab_block_3R'],
    'obliques':   ['left_oblique', 'right_oblique'],
    'quads':      ['left_quad_main', 'left_quad_inner', 'left_quad_mid',
                   'right_quad_main', 'right_quad_inner', 'right_quad_mid'],
    'calves':     ['left_calf_outer', 'left_calf_inner', 'left_calf_upper',
                   'right_calf_outer', 'right_calf_inner', 'right_calf_upper'],
    'traps':      ['traps_upper', 'traps_mid'],
}

# Region constraints for muscles that share components with other regions.
# Format: {seed_key: {'include': [(x1,y1,x2,y2), ...], 'exclude': [...]}}
# After getting the component pixels, only keep those inside include boxes
# and outside exclude boxes.
OBLIQUE_REGIONS = {
    'left_oblique': {
        'include': [(230, 370, 305, 620)],
        'exclude': [(306, 389, 395, 500)],  # abs blocks area
    },
    'right_oblique': {
        'include': [(400, 370, 476, 620)],
        'exclude': [(306, 389, 395, 500)],  # abs blocks area
    },
}


def load_image(path):
    return Image.open(path).convert('RGBA')


def build_wall_mask(img):
    """Create a boolean wall mask from the image. Walls = dark OR transparent pixels."""
    w, h = img.size
    px = img.load()
    wall = [[False] * w for _ in range(h)]
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            lum = (r * 299 + g * 587 + b * 114) // 1000
            if a < ALPHA_WALL or lum < WALL_LUM:
                wall[y][x] = True
    return wall


def dilate_walls(wall, w, h, radius):
    """Expand wall pixels by radius to close anti-aliasing gaps."""
    orig = [row[:] for row in wall]
    for y in range(h):
        for x in range(w):
            if orig[y][x]:
                for dy in range(-radius, radius + 1):
                    for dx in range(-radius, radius + 1):
                        ny, nx = y + dy, x + dx
                        if 0 <= nx < w and 0 <= ny < h:
                            wall[ny][nx] = True


def compute_components(wall, w, h):
    """Find all connected components of non-wall pixels.
    Returns labels (2D array) and component dict {id: set_of_pixels}."""
    labels = [[-1] * w for _ in range(h)]
    components = {}
    for sy in range(h):
        for sx in range(w):
            if wall[sy][sx] or labels[sy][sx] != -1:
                continue
            cid = len(components)
            q = deque([(sx, sy)])
            labels[sy][sx] = cid
            pixels = set()
            while q:
                x, y = q.popleft()
                pixels.add((x, y))
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h and not wall[ny][nx] and labels[ny][nx] == -1:
                        labels[ny][nx] = cid
                        q.append((nx, ny))
            components[cid] = pixels
    return labels, components


def map_seeds_to_components(seeds, labels, w, h):
    """Map each seed name to the component ID it falls in."""
    result = {}
    for name, points in seeds.items():
        cids = set()
        for x, y in points:
            if 0 <= x < w and 0 <= y < h:
                cid = labels[y][x]
                if cid >= 0:
                    cids.add(cid)
        if cids:
            result[name] = cids
        else:
            print(f'  WARNING: {name} seeds {points} all hit walls!')
            result[name] = set()
    return result


def filter_region(pixels, include_boxes, exclude_boxes):
    """Filter pixel set to keep only those inside include boxes and outside exclude boxes."""
    result = set()
    for x, y in pixels:
        in_include = any(x1 <= x <= x2 and y1 <= y <= y2 for x1, y1, x2, y2 in include_boxes)
        if not in_include:
            continue
        in_exclude = any(x1 <= x <= x2 and y1 <= y <= y2 for x1, y1, x2, y2 in exclude_boxes)
        if in_exclude:
            continue
        result.add((x, y))
    return result


def extract_obliques_from_image(img, abs_png_path, w, h):
    """Create oblique overlays by sampling the original image in the oblique regions,
    excluding abs block areas. This bypasses connected-component issues."""
    px = img.load()

    # Load abs overlay to know where abs blocks are
    abs_img = Image.open(abs_png_path).convert('RGBA')
    abs_px = abs_img.load()

    # Define oblique bounding boxes (anatomical side torso regions)
    regions = {
        'left_oblique': {
            'box': (230, 370, 305, 555),   # x1, y1, x2, y2 — trimmed below waist
        },
        'right_oblique': {
            'box': (400, 370, 476, 555),
        },
    }

    result = {}
    for name, info in regions.items():
        x1, y1, x2, y2 = info['box']
        pixels = set()
        for y in range(max(0, y1), min(h, y2 + 1)):
            for x in range(max(0, x1), min(w, x2 + 1)):
                r, g, b, a = px[x, y]
                lum = (r * 299 + g * 587 + b * 114) // 1000
                # Keep non-dark, non-transparent pixels (body fill)
                if a > 50 and lum >= WALL_LUM:
                    # Exclude if it's part of an abs block
                    ar, ag, ab, aa = abs_px[x, y]
                    if aa > 128 and ar > 200:  # white pixel in abs overlay
                        continue
                    # Also exclude dark line art pixels
                    if lum < WALL_LUM:
                        continue
                    pixels.add((x, y))
        result[name] = pixels
        print(f'  {name} (image extraction): {len(pixels)} px')
    return result


def extract_lower_abs_from_image(img, abs_png_path, w, h):
    """Extract lower abdominal region (below six-pack blocks) from the image."""
    px = img.load()
    abs_img = Image.open(abs_png_path).convert('RGBA')
    abs_px = abs_img.load()

    # Lower abs: below the six-pack blocks (y>500), between obliques (x=305-400)
    x1, y1, x2, y2 = 305, 500, 400, 610
    pixels = set()
    for y in range(max(0, y1), min(h, y2 + 1)):
        for x in range(max(0, x1), min(w, x2 + 1)):
            r, g, b, a = px[x, y]
            lum = (r * 299 + g * 587 + b * 114) // 1000
            if a > 50 and lum >= WALL_LUM:
                # Exclude abs blocks
                ar, ag, ab, aa = abs_px[x, y]
                if aa > 128 and ar > 200:
                    continue
                if lum < WALL_LUM:
                    continue
                pixels.add((x, y))
    print(f'  lower_abs (image extraction): {len(pixels)} px')
    return pixels


def extract_forearms_from_image(img, w, h):
    """Extract forearm regions from the image, excluding hands.
    Uses anatomical bounding boxes for forearms and excludes hand areas."""
    px = img.load()

    # Forearm regions: between elbow (~y=440) and wrist (~y=560)
    # Exclude hand regions: left hand x<110 y>530, right hand x>590 y>530
    regions = {
        'left_forearm': {
            'box': (80, 440, 210, 580),
            'exclude': [(19, 530, 110, 710)],  # left hand
        },
        'right_forearm': {
            'box': (490, 440, 630, 580),
            'exclude': [(590, 530, 687, 650)],  # right hand
        },
    }

    result = {}
    for name, info in regions.items():
        x1, y1, x2, y2 = info['box']
        pixels = set()
        for y in range(max(0, y1), min(h, y2 + 1)):
            for x in range(max(0, x1), min(w, x2 + 1)):
                r, g, b, a = px[x, y]
                lum = (r * 299 + g * 587 + b * 114) // 1000
                if a > 50 and lum >= WALL_LUM:
                    # Exclude hand regions
                    in_exclude = any(
                        ex1 <= x <= ex2 and ey1 <= y <= ey2
                        for ex1, ey1, ex2, ey2 in info['exclude']
                    )
                    if in_exclude:
                        continue
                    if lum < WALL_LUM:
                        continue
                    pixels.add((x, y))
        result[name] = pixels
        print(f'  {name} (image extraction): {len(pixels)} px')
    return result


def export_muscle(pixels_set, w, h, out_path):
    """Export a set of pixel coordinates as a transparent PNG (white fill)."""
    img = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    px = img.load()
    for x, y in pixels_set:
        px[x, y] = (255, 255, 255, 255)
    img.save(out_path)


def create_body_outline(img, wall, w, h, out_path):
    """Create outline-only layer: dark pixels on transparent background."""
    out = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    opx = out.load()
    ipx = img.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = ipx[x, y]
            lum = (r * 299 + g * 587 + b * 114) // 1000
            if a > 180 and lum < WALL_LUM:
                opx[x, y] = (30, 30, 30, 255)
    out.save(out_path)


def main():
    os.makedirs(OUTDIR, exist_ok=True)

    img = load_image(INPUT)
    w, h = img.size
    print(f'Loaded {INPUT}: {w}x{h}')

    # Build wall mask
    print('Building wall mask...')
    wall = build_wall_mask(img)
    wall_count = sum(sum(row) for row in wall)
    print(f'  Walls: {wall_count} px ({wall_count*100//(w*h)}%)')

    # Add artificial separator walls to prevent cross-muscle contamination
    print('Adding separator walls...')
    # Arm-torso separators: vertical walls separating arms from obliques
    for y in range(280, 560):
        for dx in range(4):
            if 230+dx < w: wall[y][230+dx] = True   # left arm-torso boundary
            if 476+dx < w: wall[y][476+dx] = True   # right arm-torso boundary
    # Wrist separators: horizontal walls preventing hands from joining forearms
    for x in range(50, 220):
        for dy in range(3):
            if 645+dy < h: wall[645+dy][x] = True   # left wrist
    for x in range(490, 660):
        for dy in range(3):
            if 645+dy < h: wall[645+dy][x] = True   # right wrist

    # Dilate walls to close gaps
    print(f'Dilating walls by {DILATE_RADIUS}px...')
    dilate_walls(wall, w, h, DILATE_RADIUS)
    wall_count2 = sum(sum(row) for row in wall)
    print(f'  Walls after dilation: {wall_count2} px ({wall_count2*100//(w*h)}%)')

    # Compute connected components
    print('Computing connected components...')
    labels, components = compute_components(wall, w, h)
    print(f'  Found {len(components)} components')

    # Print top components for verification
    ranked = sorted(components.items(), key=lambda c: -len(c[1]))
    print('  Top 30 components:')
    for cid, px_set in ranked[:30]:
        xs = [p[0] for p in px_set]
        ys = [p[1] for p in px_set]
        print(f'    comp#{cid}: {len(px_set):>6} px  bbox=({min(xs)},{min(ys)})-({max(xs)},{max(ys)})  cx={sum(xs)//len(xs)} cy={sum(ys)//len(ys)}')

    # Map seeds to components
    print('\nMapping seeds to components...')
    seed_map = map_seeds_to_components(SEEDS, labels, w, h)
    for name, cids in seed_map.items():
        total_px = sum(len(components[c]) for c in cids)
        print(f'  {name} -> components {cids} ({total_px} px)')

    # Merge into muscle groups
    print('\nExporting muscle groups...')
    for group_name, seed_keys in MUSCLE_GROUPS.items():
        # Skip obliques and forearms — extracted from image directly
        if group_name in ('obliques', 'forearms'):
            continue

        all_pixels = set()
        for sk in seed_keys:
            if sk in seed_map:
                for cid in seed_map[sk]:
                    all_pixels |= components[cid]

        if not all_pixels:
            print(f'  SKIP {group_name} (no pixels)')
            continue
        out_path = os.path.join(OUTDIR, f'{group_name}.png')
        export_muscle(all_pixels, w, h, out_path)
        print(f'  {group_name}: {len(all_pixels):>6} px -> {out_path}')

    # Extract obliques from image (bypasses component connectivity issues)
    print('\nExtracting obliques from image...')
    oblique_pixels = extract_obliques_from_image(
        img, os.path.join(OUTDIR, 'abs.png'), w, h
    )
    all_oblique = set()
    for pixels in oblique_pixels.values():
        all_oblique |= pixels
    if all_oblique:
        out_path = os.path.join(OUTDIR, 'obliques.png')
        export_muscle(all_oblique, w, h, out_path)
        print(f'  obliques: {len(all_oblique):>6} px -> {out_path}')
    else:
        print('  SKIP obliques (no pixels)')

    # Add lower abs to the abs overlay
    print('\nAdding lower abs to abs overlay...')
    lower_abs = extract_lower_abs_from_image(
        img, os.path.join(OUTDIR, 'abs.png'), w, h
    )
    if lower_abs:
        # Load existing abs overlay and add lower abs pixels
        abs_out = Image.open(os.path.join(OUTDIR, 'abs.png')).convert('RGBA')
        abs_pxa = abs_out.load()
        for x, y in lower_abs:
            abs_pxa[x, y] = (255, 255, 255, 255)
        abs_out.save(os.path.join(OUTDIR, 'abs.png'))
        print(f'  abs (with lower): updated')

    # Extract forearms from image (excludes hands)
    print('\nExtracting forearms from image...')
    forearm_pixels = extract_forearms_from_image(img, w, h)
    all_forearm = set()
    for pixels in forearm_pixels.values():
        all_forearm |= pixels
    if all_forearm:
        out_path = os.path.join(OUTDIR, 'forearms.png')
        export_muscle(all_forearm, w, h, out_path)
        print(f'  forearms: {len(all_forearm):>6} px -> {out_path}')
    else:
        print('  SKIP forearms (no pixels)')

    # Create body outline
    print('\nCreating body outline...')
    create_body_outline(img, wall, w, h, os.path.join(OUTDIR, 'body_outline.png'))
    print(f'  body_outline.png')

    # Save config
    config = {
        'image_width': w,
        'image_height': h,
        'muscles': {name: {'label': name.replace('_', ' ').title()}
                    for name in MUSCLE_GROUPS}
    }
    with open(os.path.join(OUTDIR, 'muscle_config.json'), 'w') as f:
        json.dump(config, f, indent=2)
    print(f'\nConfig saved to {OUTDIR}/muscle_config.json')
    print('Done!')


if __name__ == '__main__':
    main()
