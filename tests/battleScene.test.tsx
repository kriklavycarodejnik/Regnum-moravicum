import { describe, it, expect } from 'vitest';
import { render } from '@testing-library/react';
import { BattleScene } from '../src/ui/components/BattleScene';
import type { Terrain } from '../src/battle/types';

describe('BattleScene', () => {
  const terrains: Terrain[] = ['field', 'forest', 'fortress', 'river', 'hill'];

  it.each(terrains)('renders without throwing for terrain "%s"', (terrain) => {
    const { container } = render(<BattleScene terrain={terrain} />);
    expect(container.querySelector('svg')).not.toBeNull();
  });
});
