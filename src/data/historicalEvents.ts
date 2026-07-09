// Regnum Moravicum v2.1 - Event Templates (Phase 3 M1)
//
// Static templates consumed by src/core/engines/eventEngine.ts. Faction ids
// are generated non-deterministically at runtime (Date.now()-based), so
// templates key moodChanges by faction NAME (matched by id-or-name in the
// engine) rather than by id. Zupa ids are deterministic slugs of their
// canon names (e.g. "Nitra" -> "zupa_nitra"), so zupaLoyaltyChanges/zupaLoyalty
// conditions may reference them directly.
import type { GameEvent } from '../core/types/events';

const HISTORICAL_EVENTS: GameEvent[] = [
  {
    id: 'hist_papal_legation_903',
    type: 'historical',
    title: 'Pápežské posolstvo',
    description:
      'Do Nitry prichádza posolstvo z Ríma s ponukou cirkevnej podpory výmenou za uznanie rímskej jurisdikcie nad moravskou cirkvou.',
    conditions: [{ year: 903 }],
    choices: [
      {
        text: 'Prijať posolstvo a priblížiť sa Rímu',
        effects: {},
        religionChange: -15,
        prestigeChange: 3,
        moodChanges: { 'Cyrilometodskí Kňazi': { trust: -5 } },
      },
      {
        text: 'Zdvorilo odmietnuť a zachovať cyrilometodské dedičstvo',
        effects: {},
        religionChange: 5,
        moodChanges: { 'Cyrilometodskí Kňazi': { loyalty: 10, trust: 5 } },
      },
    ],
    triggered: false,
    once: true,
  },
  {
    id: 'hist_byzantine_envoy_904',
    type: 'historical',
    title: 'Byzantské posolstvo',
    description:
      'Konštantínopol ponúka Morave obchodné výsady a vojenských poradcov výmenou za bližšie cirkevné a diplomatické zblíženie.',
    conditions: [{ year: 904 }],
    choices: [
      {
        text: 'Prijať ponuku Konštantínopolu',
        effects: {},
        religionChange: 15,
        resourceChanges: { gold: 30 },
        moodChanges: { 'Byzantskí Poslovia': { trust: 15, loyalty: 10 } },
      },
      {
        text: 'Zachovať odstup od oboch cirkevných centier',
        effects: {},
        moodChanges: { 'Byzantskí Poslovia': { trust: -5 } },
      },
    ],
    triggered: false,
    once: true,
  },
  {
    id: 'hist_german_ultimatum_910',
    type: 'historical',
    title: 'Nemecké ultimátum',
    description:
      'Nemeckí kolonisti na severných hraniciach žiadajú väčšiu samosprávu a hrozia povstaním, ak im kráľovský dvor nevyjde v ústrety.',
    conditions: [{ year: 910 }],
    choices: [
      {
        text: 'Udeliť kolonistom širšiu samosprávu',
        effects: {},
        moodChanges: { 'Nemeckí Kolonisti': { loyalty: 20, trust: 15 } },
        prestigeChange: -2,
      },
      {
        text: 'Odmietnuť a poslať posily na hranicu',
        effects: {},
        moodChanges: { 'Nemeckí Kolonisti': { fear: 20, anger: 15 } },
        prestigeChange: 3,
      },
    ],
    triggered: false,
    once: true,
  },
  {
    id: 'hist_bogata_conspiracy_915',
    type: 'historical',
    title: 'Sprisahanie rodu Bogata',
    description:
      'Z Užskej župy prichádzajú správy o tajných stretnutiach rodu Bogata s nespokojnými županmi - príprava na uzurpáciu trónu.',
    conditions: [{ year: 915 }],
    choices: [
      {
        text: 'Preventívne zatknúť vodcov sprisahania',
        effects: {},
        moodChanges: { Bogatovci: { fear: 25, anger: 20 } },
        prestigeChange: 5,
      },
      {
        text: 'Sledovať a zhromažďovať dôkazy',
        effects: {},
        moodChanges: { Bogatovci: { fear: 5 } },
      },
    ],
    triggered: false,
    once: true,
  },
  {
    id: 'rand_bad_harvest',
    type: 'random',
    title: 'Neúroda',
    description: 'Chladné a daždivé leto zničilo veľkú časť úrody v jednej zo žúp.',
    conditions: [{ yearMin: 903 }],
    choices: [
      {
        text: 'Otvoriť kráľovské sklady pre postihnutú župu',
        effects: {},
        resourceChanges: { food: -20, gold: -10 },
      },
      {
        text: 'Nechať župu, nech si poradí sama',
        effects: {},
        resourceChanges: { food: -10 },
        prestigeChange: -3,
      },
    ],
    triggered: false,
    once: false,
    cooldownTicks: 24,
    weight: 15,
  },
  {
    id: 'rand_traveling_merchant',
    type: 'random',
    title: 'Potulný kupec',
    description: 'Bohatý kupec z Byzancie ponúka na kráľovskom dvore vzácne tovary a informácie výmenou za zlato.',
    conditions: [{ yearMin: 903 }],
    choices: [
      {
        text: 'Kúpiť tovar aj informácie',
        effects: {},
        resourceChanges: { gold: -25, prestige: 5 },
      },
      {
        text: 'Poďakovať a odmietnuť',
        effects: {},
      },
    ],
    triggered: false,
    once: false,
    cooldownTicks: 18,
    weight: 12,
  },
  {
    id: 'rand_noble_feud',
    type: 'diplomatic',
    title: 'Spor medzi šľachtou',
    description: 'Dvaja poprední župani sa dostali do sporu o hranice svojich žúp a žiadajú kráľovský rozsudok.',
    conditions: [{ yearMin: 903 }],
    choices: [
      {
        text: 'Rozsúdiť v prospech staršieho práva',
        effects: {},
        moodChanges: { Župani: { trust: 10 } },
      },
      {
        text: 'Nechať spor nevyriešený, aby si oslabili navzájom silu',
        effects: {},
        moodChanges: { Župani: { trust: -10, fear: 5 } },
      },
    ],
    triggered: false,
    once: false,
    cooldownTicks: 20,
    weight: 10,
  },
  {
    id: 'rand_border_raid',
    type: 'military',
    title: 'Nájazd na hranicu',
    description: 'Ozbrojená skupina prepadla pohraničnú osadu a odohnala dobytok skôr, než dorazila posádka.',
    conditions: [{ yearMin: 903 }],
    choices: [
      {
        text: 'Vyslať jazdu na prenasledovanie',
        effects: {},
        resourceChanges: { gold: -10 },
        prestigeChange: 2,
      },
      {
        text: 'Posilniť miestnu posádku a nechať nájazdníkov utiecť',
        effects: {},
        resourceChanges: { gold: -15 },
      },
    ],
    triggered: false,
    once: false,
    cooldownTicks: 15,
    weight: 12,
  },
  {
    id: 'rand_missionary_dispute',
    type: 'religious',
    title: 'Spor misionárov',
    description:
      'Latinskí a byzantskí misionári sa v jednej z žúp verejne pohádali o správny spôsob bohoslužby, čo znepokojuje miestnych.',
    conditions: [{ yearMin: 903 }],
    choices: [
      {
        text: 'Podporiť latinský obrad',
        effects: {},
        religionChange: -8,
        moodChanges: { 'Cyrilometodskí Kňazi': { anger: 8 } },
      },
      {
        text: 'Podporiť byzantský obrad',
        effects: {},
        religionChange: 8,
        moodChanges: { 'Byzantskí Poslovia': { trust: 8 } },
      },
      {
        text: 'Zakázať verejné spory oboch strán',
        effects: {},
        prestigeChange: 1,
      },
    ],
    triggered: false,
    once: false,
    cooldownTicks: 20,
    weight: 10,
  },
  {
    id: 'rand_court_intrigue',
    type: 'diplomatic',
    title: 'Dvorská intriga',
    description: 'Anonymný odkaz varuje kráľa pred údajnou zradou jedného z blízkych radcov.',
    conditions: [{ yearMin: 905 }],
    choices: [
      {
        text: 'Radcu potichu odstrániť z dvora',
        effects: {},
        prestigeChange: -1,
        moodChanges: { Bogatovci: { fear: 10 } },
      },
      {
        text: 'Odkaz ignorovať ako klamstvo',
        effects: {},
      },
    ],
    triggered: false,
    once: false,
    cooldownTicks: 24,
    weight: 8,
  },
];

export default HISTORICAL_EVENTS;
export { HISTORICAL_EVENTS };
