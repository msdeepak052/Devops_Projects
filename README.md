To-Do List 3-Tier Application (React + Node.js + PostgreSQL)

Folder Structure:

```
todo-app/
├── backend/
│   ├── controllers/
│   │   └── authController.js
│   │   └── todoController.js
│   ├── models/
│   │   └── index.js
│   │   └── user.js
│   │   └── todo.js
│   ├── routes/
│   │   └── auth.js
│   │   └── todos.js
│   ├── middleware/
│   │   └── authMiddleware.js
│   ├── app.js
│   ├── config.js
│   ├── Dockerfile
│   └── package.json
│
├── frontend/
│   ├── public/
│   │   └── index.html
│   ├── src/
│   │   ├── components/
│   │   │   └── Login.js
│   │   │   └── Register.js
│   │   │   └── TodoList.js
│   │   ├── App.js
│   │   ├── index.js
│   │   └── App.css
│   ├── Dockerfile
│   └── package.json
│
├── database/
│   └── init.sql
│   └── Dockerfile
│
├── docker-compose.yml
├── README.md
```

### Key Features:
- User Registration and Login with JWT
- Task creation, update, deletion
- Auth-protected routes
- PostgreSQL DB with Sequelize ORM

### Backend Code

#### `backend/package.json`
```json
{
  "name": "todo-backend",
  "version": "1.0.0",
  "main": "app.js",
  "scripts": {
    "start": "node app.js"
  },
  "dependencies": {
    "bcryptjs": "^2.4.3",
    "cors": "^2.8.5",
    "dotenv": "^16.0.3",
    "express": "^4.18.2",
    "jsonwebtoken": "^9.0.0",
    "pg": "^8.8.0",
    "pg-hstore": "^2.3.4",
    "sequelize": "^6.28.0"
  }
}
```

#### `backend/app.js`
```js
const express = require('express');
const cors = require('cors');
require('dotenv').config();
const authRoutes = require('./routes/auth');
const todoRoutes = require('./routes/todos');
const db = require('./models');

const app = express();

app.use(cors());
app.use(express.json());

app.use('/api/auth', authRoutes);
app.use('/api/todos', todoRoutes);

const PORT = process.env.PORT || 5000;
db.sequelize.sync().then(() => {
  app.listen(PORT, () => console.log(`Server running on port ${PORT}`));
});
```

#### `backend/config.js`
```js
require('dotenv').config();

module.exports = {
  secret: process.env.JWT_SECRET || 'secretkey',
  db: {
    DB: process.env.DB_NAME,
    USER: process.env.DB_USER,
    PASSWORD: process.env.DB_PASSWORD,
    HOST: process.env.DB_HOST,
    dialect: 'postgres',
  }
};
```

#### `backend/models/index.js`
```js
const Sequelize = require('sequelize');
const config = require('../config').db;

const sequelize = new Sequelize(config.DB, config.USER, config.PASSWORD, {
  host: config.HOST,
  dialect: config.dialect,
});

const db = {};
db.Sequelize = Sequelize;
db.sequelize = sequelize;

db.User = require('./user')(sequelize, Sequelize);
db.Todo = require('./todo')(sequelize, Sequelize);

db.User.hasMany(db.Todo);
db.Todo.belongsTo(db.User);

module.exports = db;
```

#### `backend/models/user.js`
```js
module.exports = (sequelize, DataTypes) => {
  return sequelize.define('User', {
    username: { type: DataTypes.STRING, unique: true },
    password: { type: DataTypes.STRING },
  });
};
```

#### `backend/models/todo.js`
```js
module.exports = (sequelize, DataTypes) => {
  return sequelize.define('Todo', {
    title: { type: DataTypes.STRING },
    completed: { type: DataTypes.BOOLEAN, defaultValue: false },
  });
};
```

#### `backend/routes/auth.js`
```js
const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { User } = require('../models');
const { secret } = require('../config');

const router = express.Router();

router.post('/register', async (req, res) => {
  const { username, password } = req.body;
  const hash = await bcrypt.hash(password, 10);
  try {
    const user = await User.create({ username, password: hash });
    res.status(201).json({ message: 'User registered' });
  } catch {
    res.status(400).json({ message: 'User already exists' });
  }
});

router.post('/login', async (req, res) => {
  const { username, password } = req.body;
  const user = await User.findOne({ where: { username } });
  if (!user || !(await bcrypt.compare(password, user.password)))
    return res.status(401).json({ message: 'Invalid credentials' });

  const token = jwt.sign({ id: user.id }, secret, { expiresIn: '1d' });
  res.json({ token });
});

module.exports = router;
```

#### `backend/routes/todos.js`
```js
const express = require('express');
const { Todo } = require('../models');
const auth = require('../middleware/authMiddleware');

const router = express.Router();

router.use(auth);

router.get('/', async (req, res) => {
  const todos = await Todo.findAll({ where: { UserId: req.userId } });
  res.json(todos);
});

router.post('/', async (req, res) => {
  const todo = await Todo.create({ ...req.body, UserId: req.userId });
  res.json(todo);
});

router.put('/:id', async (req, res) => {
  const todo = await Todo.findByPk(req.params.id);
  if (todo && todo.UserId === req.userId) {
    await todo.update(req.body);
    res.json(todo);
  } else res.status(404).json({ message: 'Not found' });
});

router.delete('/:id', async (req, res) => {
  const todo = await Todo.findByPk(req.params.id);
  if (todo && todo.UserId === req.userId) {
    await todo.destroy();
    res.json({ message: 'Deleted' });
  } else res.status(404).json({ message: 'Not found' });
});

module.exports = router;
```

#### `backend/middleware/authMiddleware.js`
```js
const jwt = require('jsonwebtoken');
const { secret } = require('../config');

module.exports = (req, res, next) => {
  const token = req.headers['authorization'];
  if (!token) return res.status(403).json({ message: 'No token provided' });
  try {
    const decoded = jwt.verify(token, secret);
    req.userId = decoded.id;
    next();
  } catch (err) {
    res.status(401).json({ message: 'Unauthorized' });
  }
};
```

#### `backend/Dockerfile`
```Dockerfile
FROM node:18-alpine
WORKDIR /app
COPY package.json .
RUN npm install
COPY . .
EXPOSE 5000
CMD ["npm", "start"]
```


#### `backend/controllers/authController.js`
```js
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { User } = require('../models');
const { secret } = require('../config');

exports.register = async (req, res) => {
  const { username, password } = req.body;
  try {
    const hash = await bcrypt.hash(password, 10);
    const user = await User.create({ username, password: hash });
    res.status(201).json({ message: 'User registered' });
  } catch (err) {
    res.status(400).json({ message: 'User already exists' });
  }
};

exports.login = async (req, res) => {
  const { username, password } = req.body;
  const user = await User.findOne({ where: { username } });
  if (!user || !(await bcrypt.compare(password, user.password))) {
    return res.status(401).json({ message: 'Invalid credentials' });
  }
  const token = jwt.sign({ id: user.id }, secret, { expiresIn: '1d' });
  res.json({ token });
};
```

#### `backend/controllers/todoController.js`
```js
const { Todo } = require('../models');

exports.getTodos = async (req, res) => {
  const todos = await Todo.findAll({ where: { UserId: req.userId } });
  res.json(todos);
};

exports.createTodo = async (req, res) => {
  const todo = await Todo.create({ ...req.body, UserId: req.userId });
  res.json(todo);
};

exports.updateTodo = async (req, res) => {
  const todo = await Todo.findByPk(req.params.id);
  if (todo && todo.UserId === req.userId) {
    await todo.update(req.body);
    res.json(todo);
  } else {
    res.status(404).json({ message: 'Not found' });
  }
};

exports.deleteTodo = async (req, res) => {
  const todo = await Todo.findByPk(req.params.id);
  if (todo && todo.UserId === req.userId) {
    await todo.destroy();
    res.json({ message: 'Deleted' });
  } else {
    res.status(404).json({ message: 'Not found' });
  }
};
```

### Key Features:
- User Registration and Login with JWT
- Task creation, update, deletion
- Auth-protected routes
- PostgreSQL DB with Sequelize ORM


### Frontend Code

#### `frontend/public/index.html`
```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>To-Do App</title>
</head>
<body>
  <div id="root"></div>
</body>
</html>
```

#### `frontend/src/index.js`
```js
import React from 'react';
import ReactDOM from 'react-dom';
import App from './App';
import './App.css';

ReactDOM.render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
  document.getElementById('root')
);
```

#### `frontend/src/App.js`
```js
import React, { useState, useEffect } from 'react';
import Login from './components/Login';
import Register from './components/Register';
import TodoList from './components/TodoList';

function App() {
  const [token, setToken] = useState(localStorage.getItem('token'));

  const handleLogin = (token) => {
    localStorage.setItem('token', token);
    setToken(token);
  };

  const handleLogout = () => {
    localStorage.removeItem('token');
    setToken(null);
  };

  if (!token) {
    return (
      <div>
        <h2>Login</h2>
        <Login onLogin={handleLogin} />
        <h2>Register</h2>
        <Register />
      </div>
    );
  }

  return <TodoList token={token} onLogout={handleLogout} />;
}

export default App;
```

#### `frontend/src/App.css`
```css
body {
  font-family: Arial, sans-serif;
  background: #f2f2f2;
  margin: 0;
  padding: 20px;
}
input, button {
  margin: 5px;
  padding: 8px;
}
```

#### `frontend/src/components/Login.js`
```js
import React, { useState } from 'react';

const Login = ({ onLogin }) => {
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');

  const handleSubmit = async (e) => {
    e.preventDefault();
    const res = await fetch('/api/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username, password }),
    });
    const data = await res.json();
    if (res.ok) onLogin(data.token);
    else alert(data.message);
  };

  return (
    <form onSubmit={handleSubmit}>
      <input placeholder="Username" value={username} onChange={(e) => setUsername(e.target.value)} />
      <input type="password" placeholder="Password" value={password} onChange={(e) => setPassword(e.target.value)} />
      <button type="submit">Login</button>
    </form>
  );
};

export default Login;
```

#### `frontend/src/components/Register.js`
```js
import React, { useState } from 'react';

const Register = () => {
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');

  const handleSubmit = async (e) => {
    e.preventDefault();
    const res = await fetch('/api/auth/register', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username, password }),
    });
    const data = await res.json();
    if (res.ok) alert('Registered! You can log in now.');
    else alert(data.message);
  };

  return (
    <form onSubmit={handleSubmit}>
      <input placeholder="Username" value={username} onChange={(e) => setUsername(e.target.value)} />
      <input type="password" placeholder="Password" value={password} onChange={(e) => setPassword(e.target.value)} />
      <button type="submit">Register</button>
    </form>
  );
};

export default Register;
```

#### `frontend/src/components/TodoList.js`
```js
import React, { useState, useEffect } from 'react';

const TodoList = ({ token, onLogout }) => {
  const [todos, setTodos] = useState([]);
  const [task, setTask] = useState('');

  const fetchTodos = async () => {
    const res = await fetch('/api/todos', {
      headers: { Authorization: `Bearer ${token}` },
    });
    const data = await res.json();
    setTodos(data);
  };

  const addTodo = async () => {
    const res = await fetch('/api/todos', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${token}`,
      },
      body: JSON.stringify({ task }),
    });
    if (res.ok) {
      setTask('');
      fetchTodos();
    }
  };

  const deleteTodo = async (id) => {
    await fetch(`/api/todos/${id}`, {
      method: 'DELETE',
      headers: { Authorization: `Bearer ${token}` },
    });
    fetchTodos();
  };

  useEffect(() => {
    fetchTodos();
  }, []);

  return (
    <div>
      <button onClick={onLogout}>Logout</button>
      <h2>Your Todos</h2>
      <input value={task} onChange={(e) => setTask(e.target.value)} placeholder="New task" />
      <button onClick={addTodo}>Add</button>
      <ul>
        {todos.map((t) => (
          <li key={t.id}>
            {t.task} <button onClick={() => deleteTodo(t.id)}>Delete</button>
          </li>
        ))}
      </ul>
    </div>
  );
};

export default TodoList;
```
