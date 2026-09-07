# Derive app UI roles without changing the ANSI palette used by terminal output.
import re
import sys


def blend(front, back, amount):
    return '#' + ''.join(f'{round(int(front[i:i+2], 16) * amount + int(back[i:i+2], 16) * (1-amount)):02x}' for i in (1, 3, 5))


def luminance(color):
    channels = [int(color[i:i+2], 16) / 255 for i in (1, 3, 5)]
    return sum(weight * (c / 12.92 if c <= .04045 else ((c + .055) / 1.055) ** 2.4) for c, weight in zip(channels, (.2126, .7152, .0722)))


def contrast(a, b):
    low, high = sorted((luminance(a), luminance(b)))
    return (high + .05) / (low + .05)


def readable(color, background, minimum=4.5):
    target = max(('#000000', '#ffffff'), key=lambda c: contrast(c, background))
    for step in range(101):
        candidate = blend(target, color, step / 100)
        if contrast(candidate, background) >= minimum:
            return candidate
    return target


def derive(bg, fg, *accents):
    surface = blend(fg, bg, .07)
    colors = {name: readable(color, surface) for name, color in zip(('red', 'green', 'yellow', 'blue', 'magenta', 'cyan'), accents)}
    selection = blend(colors['blue'], bg, .25)
    roles = dict(bg=bg, fg=readable(fg, surface), surface=surface,
                 muted=readable(blend(fg, bg, .55), surface),
                 border=blend(fg, bg, .3), selection=selection,
                 selection_fg=readable(fg, selection), **colors)
    for name, color in colors.items():
        roles['on_' + name] = readable(bg, color)
    return roles


if __name__ == '__main__':
    values = sys.argv[1:]
    if len(values) != 8 or not all(re.fullmatch(r'#[0-9a-fA-F]{6}', value) for value in values):
        sys.exit('Expected background, foreground, and six ANSI accent colors')
    for key, value in derive(*values).items():
        print(f'theme_ui_{key}={value}')
