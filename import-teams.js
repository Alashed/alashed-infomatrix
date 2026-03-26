require('dotenv').config();
const { Pool } = require('pg');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false }
});

const TEAMS = [
  {
    id: 1,
    name: "TECHNO MUSCLE",
    country: "Kazakhstan",
    members: ["Danyshbaev Dias", "Kalyk Amir", "Ushkov Timofey"],
    color: "#ef4444"
  },
  {
    id: 2,
    name: "DoubleAoneZ",
    country: "Kazakhstan",
    members: ["Muratkanov Alikhan", "Nurpeyis Abylai", "Kuanysheva Zhasmin"],
    color: "#f97316"
  },
  {
    id: 3,
    name: "Aqtobe BIL",
    country: "Kazakhstan",
    members: ["Akylbek Sardar", "Amangos Omaralim", "Zhandosuly Zhanserik"],
    color: "#fbbf24"
  },
  {
    id: 4,
    name: "Petro BIL",
    country: "Kazakhstan",
    members: ["TEMIRKHAN ALKEN", "Orazbay Arsen", "Raushan Yernar"],
    color: "#84cc16"
  },
  {
    id: 5,
    name: "L33TechForce",
    country: "Kazakhstan",
    members: ["Gabduakhit Alibi", "Utepova Dinara", "Nasipkali Aigerim"],
    color: "#22c55e"
  },
  {
    id: 6,
    name: "MrBig",
    country: "Kazakhstan",
    members: ["Sagymbaev Islam", "Nurzhanuly Mukhtar", "Zhansoltan Yerzhan"],
    color: "#10b981"
  },
  {
    id: 7,
    name: "WinLeaders",
    country: "Kazakhstan",
    members: ["Nurmukhambet Zhanibek", "Sadyrbek Mukhammadali", "Kochkarov Ilyas"],
    color: "#14b8a6"
  },
  {
    id: 8,
    name: "NextGen Tech Girls",
    country: "Tajikistan",
    members: ["Nasrieva Humairo", "Ashurova Maryam", "Khoshimova Anusha"],
    color: "#06b6d4"
  },
  {
    id: 9,
    name: "infiNIS",
    country: "Kazakhstan",
    members: ["Myktybayev Daulet", "Malikov Imran", "Ayazbayuly Bakdaulet"],
    color: "#3b82f6"
  },
  {
    id: 10,
    name: "TKRobotics",
    country: "Kazakhstan",
    members: ["Sharipov Nurassyl", "Akhmatulin Syrym", "Buzykin Alexey"],
    color: "#6366f1"
  },
  {
    id: 11,
    name: "NOMAD ROBOTICS",
    country: "Kazakhstan",
    members: ["Ahmedhozha Alhan", "Konysbek Abdulla", "Kaldybai Erzat"],
    color: "#8b5cf6"
  }
];

async function importTeams() {
  try {
    // Get current state
    const res = await pool.query('SELECT data FROM game_state WHERE id = 1');
    let state = res.rows.length ? res.rows[0].data : { teams: [], fields: [], matches: [] };

    // Update teams
    state.teams = TEAMS.map(team => ({
      id: team.id,
      name: team.name,
      country: team.country || "Kazakhstan",
      color: team.color,
      members: team.members,
      teamForm: 0,
      buildTime: null,
      tableDecor: 0,
      teamSpirit: 0,
      engineering: 0,
      robotDesign: 0,
      presentation: 0
    }));

    // Save back to database
    await pool.query(`
      INSERT INTO game_state (id, data, updated_at) VALUES (1, $1, NOW())
      ON CONFLICT (id) DO UPDATE SET data = $1, updated_at = NOW()
    `, [state]);

    console.log('✅ Successfully imported all 11 teams!');
    console.log(`   Total teams: ${state.teams.length}`);

    state.teams.forEach(team => {
      console.log(`   ${team.id}. ${team.name} (${team.country}) - ${team.members.join(', ')}`);
    });

    await pool.end();
  } catch (err) {
    console.error('❌ Error:', err.message);
    process.exit(1);
  }
}

importTeams();
