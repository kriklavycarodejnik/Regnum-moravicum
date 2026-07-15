// Regnum Moravicum v2.1 - Fallback Decision Pool (Core Loop M2)
//
// Minor, dobové kronikárske eventy s voľbou, consumed only by
// src/core/engines/decisionScheduler.ts as a last-resort source when no
// other decision (pending event / faction demand / investment opportunity)
// is available for the tick. Cooldown-gated the same way historical/random
// templates are in src/core/engines/eventEngine.ts, so the same handful of
// entries doesn't repeat back-to-back.
import type { GameEvent } from '../core/types/events';

export const FALLBACK_EVENTS: GameEvent[] = [
  {
    id: 'fallback_market_dispute',
    type: 'random',
    title: 'Spor kupcov na trhovisku',
    description: 'Dvaja kupci sa pred súdom hádajú o váhy a miery. Dvor musí rozhodnúť, komu dať za pravdu.',
    conditions: [],
    choices: [
      { text: 'Rozhodnúť v prospech domáceho kupca', effects: {}, zupaLoyaltyChanges: {}, resourceChanges: {} },
      { text: 'Rozhodnúť podľa svedkov, nie pôvodu', effects: {}, prestigeChange: 1 },
    ],
    triggered: false,
    cooldownTicks: 15,
    weight: 10,
  },
  {
    id: 'fallback_wandering_monk',
    type: 'religious',
    title: 'Potulný mních žiada almužnu',
    description: 'Na dvor prichádza pútnik v mníšskom rúchu a prosí o almužnu pre chudobný kláštor.',
    conditions: [],
    choices: [
      { text: 'Darovať zlato kláštoru', effects: {}, resourceChanges: { gold: -20 }, prestigeChange: 2 },
      { text: 'Odmietnuť, pokladnica nie je bezodná', effects: {} },
    ],
    triggered: false,
    cooldownTicks: 18,
    weight: 10,
  },
  {
    id: 'fallback_border_skirmish',
    type: 'military',
    title: 'Hraničná potýčka pastierov',
    description: 'Pastieri z dvoch susedných žúp sa pobili o pastvinu na hranici chotára.',
    conditions: [],
    choices: [
      { text: 'Vyslať drába na vyriešenie sporu', effects: {}, resourceChanges: { gold: -10 } },
      { text: 'Nechať župana, nech si to vyrieši sám', effects: {} },
    ],
    triggered: false,
    cooldownTicks: 15,
    weight: 10,
  },
  {
    id: 'fallback_good_harvest',
    type: 'random',
    title: 'Neočakávane bohatá úroda',
    description: 'Priaznivé počasie prinieslo v jednej z žúp bohatšiu úrodu, než sa čakalo.',
    conditions: [],
    choices: [
      { text: 'Časť úrody predať na trhu', effects: {}, resourceChanges: { gold: 25, food: -10 } },
      { text: 'Uskladniť úrodu pre horšie časy', effects: {}, resourceChanges: { food: 15 } },
    ],
    triggered: false,
    cooldownTicks: 20,
    weight: 8,
  },
  {
    id: 'fallback_traveling_merchant',
    type: 'diplomatic',
    title: 'Potulný kupec ponúka tovar',
    description: 'Kupec z ďalekých krajov ponúka na dvore vzácne súkno a korenie za slušnú cenu.',
    conditions: [],
    choices: [
      { text: 'Kúpiť tovar pre dvor', effects: {}, resourceChanges: { gold: -30 }, prestigeChange: 2 },
      { text: 'Poslať kupca ďalej', effects: {} },
    ],
    triggered: false,
    cooldownTicks: 18,
    weight: 10,
  },
  {
    id: 'fallback_local_dispute',
    type: 'random',
    title: 'Spor dvoch rodov o pozemok',
    description: 'Dva zemianske rody sa dožadujú panovníkovho rozsudku vo veci sporného medzníka.',
    conditions: [],
    choices: [
      { text: 'Rozdeliť pozemok rovným dielom', effects: {} },
      { text: 'Rozhodnúť v prospech staršieho rodu', effects: {}, prestigeChange: -1 },
    ],
    triggered: false,
    cooldownTicks: 15,
    weight: 10,
  },
  {
    id: 'fallback_omen',
    type: 'religious',
    title: 'Znamenie na oblohe znepokojuje ľud',
    description: 'Nezvyčajný úkaz na nočnej oblohe rozpútal medzi ľudom reči o božom hneve alebo priazni.',
    conditions: [],
    choices: [
      { text: 'Nechať kňazov vysvetliť znamenie ako priazeň', effects: {}, prestigeChange: 2 },
      { text: 'Nevšímať si povery', effects: {} },
    ],
    triggered: false,
    cooldownTicks: 20,
    weight: 8,
  },
  {
    id: 'fallback_bandit_rumors',
    type: 'military',
    title: 'Zvesti o lupičoch na cestách',
    description: 'Kupci sa sťažujú na lupičov, ktorí prepadávajú karavány na obchodných cestách.',
    conditions: [],
    choices: [
      { text: 'Vyslať hliadku na vyčistenie ciest', effects: {}, resourceChanges: { gold: -15 } },
      { text: 'Ponechať bezpečnosť ciest na kupcov samých', effects: {} },
    ],
    triggered: false,
    cooldownTicks: 15,
    weight: 10,
  },
  {
    id: 'fallback_pilgrim_group',
    type: 'religious',
    title: 'Skupina pútnikov prechádza krajinou',
    description: 'Zástup pútnikov smerujúcich k svätým miestam žiada nocľah a ochranu na svojej ceste.',
    conditions: [],
    choices: [
      { text: 'Poskytnúť pútnikom nocľah a stravu', effects: {}, resourceChanges: { food: -10 }, prestigeChange: 1 },
      { text: 'Nasmerovať ich ďalej bez zdržania', effects: {} },
    ],
    triggered: false,
    cooldownTicks: 18,
    weight: 9,
  },
  {
    id: 'fallback_court_petition',
    type: 'diplomatic',
    title: 'Petícia dvoranov o priazeň',
    description: 'Skupina nižších zemanov predkladá panovníkovi petíciu s prosbou o väčšiu priazeň dvora.',
    conditions: [],
    choices: [
      { text: 'Vypočuť si ich a prisľúbiť podporu', effects: {}, prestigeChange: 1 },
      { text: 'Odbiť petíciu ako bezvýznamnú', effects: {}, prestigeChange: -1 },
    ],
    triggered: false,
    cooldownTicks: 15,
    weight: 10,
  },
];

export default FALLBACK_EVENTS;
