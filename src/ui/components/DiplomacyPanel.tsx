// Regnum Moravicum v2.1 - Diplomacy Panel Component
import { useState } from 'react';
import type { GameState } from '../../core/types/gameState';
import type { Faction, FactionPersonality } from '../../core/types/entities';
import type { DiplomaticActionType } from '../../core/engines/diplomacyEngine';
import styles from '../../styles/DiplomacyPanel.module.css';

interface DiplomacyPanelProps {
  gameState: GameState;
  onPerformDiplomaticAction: (factionId: string, action: DiplomaticActionType) => void;
}

const PERSONALITY_LABEL: Record<FactionPersonality, string> = {
  aggressive: 'Agresívna',
  opportunist: 'Oportunistická',
  loyal: 'Lojálna',
  traitor: 'Zradná',
};

const TREATY_TYPE_LABEL: Record<string, string> = {
  trade: 'Obchodná zmluva',
  military: 'Vojenský pakt',
  marriage: 'Manželský zväzok',
  nonAggression: 'Pakt o neútočení',
  vassal: 'Vazalstvo',
};

const FACTION_ICON_CLASS: Record<string, string> = {
  Župani: 'zupani',
  'Cyrilometodskí Kňazi': 'cyrilometodski',
  'Byzantskí Poslovia': 'byzantski',
  'Nemeckí Kolonisti': 'nemecki',
  'Maďarské zvyšky': 'madarski',
  Bogatovci: 'kumani',
};

const ACTIONS: { type: DiplomaticActionType; label: string }[] = [
  { type: 'gift', label: 'Dar (50 zlata)' },
  { type: 'threat', label: 'Vyhrážka' },
  { type: 'proposeTrade', label: 'Navrhnúť obchod' },
  { type: 'proposeNonAggression', label: 'Navrhnúť neútočenie' },
  { type: 'proposeMilitaryPact', label: 'Navrhnúť vojenský pakt' },
];

function relation(faction: Faction): { label: string; className: string } {
  const { trust, loyalty, fear, anger } = faction.moods;
  const score = (trust + loyalty) / 2 - (fear + anger) / 2;
  if (score > 60) return { label: 'Spojenecká', className: styles.relationAllied };
  if (score > 30) return { label: 'Priateľská', className: styles.relationFriendly };
  if (score > -10) return { label: 'Neutrálna', className: styles.relationNeutral };
  if (score > -40) return { label: 'Nepriateľská', className: styles.relationUnfriendly };
  return { label: 'Hostilná', className: styles.relationHostile };
}

function tickToYear(tick: number): number {
  return 902 + Math.floor(tick / 12);
}

export function DiplomacyPanel({ gameState, onPerformDiplomaticAction }: DiplomacyPanelProps) {
  const [selectedFactionId, setSelectedFactionId] = useState<string | null>(null);
  const selectedFaction = gameState.factions.find((f) => f.id === selectedFactionId) ?? null;

  const factionTreaties = selectedFaction
    ? gameState.treaties.filter((t) => t.parties.includes(selectedFaction.id) && t.endTick >= gameState.tick)
    : [];

  return (
    <div className={styles.container}>
      <div className={styles.header}>
        <h2>Diplomacia</h2>
      </div>
      <div className={styles.content}>
        <div className={styles.factionList}>
          {gameState.factions.map((faction) => {
            const rel = relation(faction);
            const isSelected = faction.id === selectedFactionId;
            return (
              <div
                key={faction.id}
                className={`${styles.factionCard} ${isSelected ? styles.selected : ''}`}
                onClick={() => setSelectedFactionId(isSelected ? null : faction.id)}
              >
                <div className={`${styles.factionIcon} ${styles[FACTION_ICON_CLASS[faction.name]] ?? ''}`}>⚑</div>
                <div className={styles.factionInfo}>
                  <p className={styles.factionName}>{faction.name}</p>
                  <p className={styles.factionTitle}>{PERSONALITY_LABEL[faction.personality]}</p>
                  <div className={styles.factionStats}>
                    <span className={`${styles.relationIndicator} ${rel.className}`}>{rel.label}</span>
                    <span className={styles.factionStat}>Dôvera: {faction.moods.trust}</span>
                    <span className={styles.factionStat}>Lojalita: {faction.moods.loyalty}</span>
                    <span className={styles.factionStat}>Strach: {faction.moods.fear}</span>
                    <span className={styles.factionStat}>Hnev: {faction.moods.anger}</span>
                  </div>
                </div>
              </div>
            );
          })}
        </div>

        {selectedFaction && (
          <div className={styles.actionsPanel}>
            <p className={styles.actionsTitle}>Aktívne zmluvy s frakciou {selectedFaction.name}</p>
            {factionTreaties.length > 0 ? (
              <div className={styles.treatyList}>
                {factionTreaties.map((treaty) => (
                  <div key={treaty.id} className={styles.treatyItem}>
                    <span className={styles.treatyType}>{TREATY_TYPE_LABEL[treaty.type] ?? treaty.type}</span>
                    <div className={styles.treatyDetails}>
                      <p className={styles.treatyText}>{TREATY_TYPE_LABEL[treaty.type] ?? treaty.type}</p>
                      <span className={styles.treatyExpiry}>platí do roku {tickToYear(treaty.endTick)}</span>
                    </div>
                  </div>
                ))}
              </div>
            ) : (
              <p className={styles.treatyExpiry}>Žiadne aktívne zmluvy</p>
            )}

            <p className={styles.actionsTitle} style={{ marginTop: 15 }}>
              Diplomatické akcie
            </p>
            <div className={styles.actionsGrid}>
              {ACTIONS.map((action) => (
                <button
                  key={action.type}
                  className={styles.actionButton}
                  disabled={action.type === 'gift' && gameState.resources.gold < 50}
                  onClick={() => onPerformDiplomaticAction(selectedFaction.id, action.type)}
                >
                  {action.label}
                </button>
              ))}
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

export default DiplomacyPanel;
