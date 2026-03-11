const express = require('express');
const router = express.Router();
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const db = require('better-sqlite3')('../../data/oa.db');

const JWT_SECRET = process.env.JWT_SECRET || 'your-super-secret-jwt-key';
const JWT_EXPIRES_IN = process.env.JWT_EXPIRES_IN || '8h';
const LOCK_TIME = 30 * 60 * 1000; // 30分钟
const MAX_LOGIN_ATTEMPTS = 5;

/**
 * POST /api/auth/check-account
 * 第一步：检查账号是否存在
 */
router.post('/check-account', (req, res) => {
  const { account } = req.body;
  
  if (!account) {
    return res.status(400).json({ code: 400, message: '请输入账号' });
  }
  
  // 判断是用户名还是手机号
  const isPhone = /^1[3-9]\d{9}$/.test(account);
  
  const user = db.prepare(`
    SELECT id, username, real_name, phone, status 
    FROM user 
    WHERE ${isPhone ? 'phone' : 'username'} = ?
  `).get(account);
  
  if (!user) {
    return res.status(404).json({ code: 404, message: '账号不存在' });
  }
  
  if (user.status === 0) {
    return res.status(403).json({ code: 403, message: '账号已被禁用' });
  }
  
  res.json({
    code: 200,
    data: {
      userId: user.id,
      username: user.username,
      realName: user.real_name,
      hasPhone: !!user.phone,
      loginType: isPhone ? 'phone' : 'username'
    }
  });
});

/**
 * POST /api/auth/send-sms
 * 发送短信验证码
 */
router.post('/send-sms', (req, res) => {
  const { phone } = req.body;
  
  if (!phone || !/^1[3-9]\d{9}$/.test(phone)) {
    return res.status(400).json({ code: 400, message: '请输入正确的手机号' });
  }
  
  // 检查60秒内是否已发送
  const recentCode = db.prepare(`
    SELECT * FROM sms_code 
    WHERE phone = ? AND created_at > datetime('now', '-60 seconds')
    ORDER BY created_at DESC LIMIT 1
  `).get(phone);
  
  if (recentCode) {
    return res.status(429).json({ 
      code: 429, 
      message: '验证码已发送，请60秒后重试' 
    });
  }
  
  // 生成6位验证码
  const code = Math.random().toString().slice(-6);
  const expireTime = new Date(Date.now() + 5 * 60 * 1000).toISOString();
  
  // 保存验证码
  db.prepare(`
    INSERT INTO sms_code (phone, code, expire_time) VALUES (?, ?, ?)
  `).run(phone, code, expireTime);
  
  // TODO: 实际发送短信（对接短信服务商）
  console.log(`[SMS] 发送验证码到 ${phone}: ${code}`);
  
  res.json({
    code: 200,
    message: '验证码已发送',
    data: { expireTime }
  });
});

/**
 * POST /api/auth/login-by-password
 * 密码登录
 */
router.post('/login-by-password', (req, res) => {
  const { account, password } = req.body;
  
  if (!account || !password) {
    return res.status(400).json({ code: 400, message: '请输入账号和密码' });
  }
  
  const isPhone = /^1[3-9]\d{9}$/.test(account);
  
  // 查找用户
  const user = db.prepare(`
    SELECT * FROM user 
    WHERE ${isPhone ? 'phone' : 'username'} = ?
  `).get(account);
  
  if (!user) {
    return res.status(404).json({ code: 404, message: '账号不存在' });
  }
  
  // 检查是否被锁定
  if (user.lock_until && new Date(user.lock_until) > new Date()) {
    const remainMinutes = Math.ceil((new Date(user.lock_until) - new Date()) / 60000);
    return res.status(403).json({ 
      code: 403, 
      message: `账号已锁定，请${remainMinutes}分钟后重试` 
    });
  }
  
  // 验证密码
  const isValid = bcrypt.compareSync(password, user.password_hash);
  
  if (!isValid) {
    // 增加失败次数
    const attempts = (user.login_attempts || 0) + 1;
    let lockUntil = null;
    
    if (attempts >= MAX_LOGIN_ATTEMPTS) {
      lockUntil = new Date(Date.now() + LOCK_TIME).toISOString();
    }
    
    db.prepare(`
      UPDATE user SET login_attempts = ?, lock_until = ? WHERE id = ?
    `).run(attempts, lockUntil, user.id);
    
    if (lockUntil) {
      return res.status(403).json({ 
        code: 403, 
        message: '密码错误5次，账号已锁定30分钟' 
      });
    }
    
    return res.status(401).json({ 
      code: 401, 
      message: `密码错误，还剩${MAX_LOGIN_ATTEMPTS - attempts}次机会` 
    });
  }
  
  // 登录成功，重置失败次数
  db.prepare(`
    UPDATE user 
    SET login_attempts = 0, lock_until = NULL, last_login_time = CURRENT_TIMESTAMP 
    WHERE id = ?
  `).run(user.id);
  
  // 生成 JWT
  const token = jwt.sign(
    { userId: user.id, username: user.username },
    JWT_SECRET,
    { expiresIn: JWT_EXPIRES_IN }
  );
  
  // 获取用户角色
  const roles = db.prepare(`
    SELECT r.code, r.name FROM role r
    JOIN user_role ur ON r.id = ur.role_id
    WHERE ur.user_id = ?
  `).all(user.id);
  
  res.json({
    code: 200,
    message: '登录成功',
    data: {
      token,
      user: {
        id: user.id,
        username: user.username,
        realName: user.real_name,
        phone: user.phone,
        email: user.email,
        deptId: user.dept_id,
        roles: roles.map(r => ({ code: r.code, name: r.name }))
      }
    }
  });
});

/**
 * POST /api/auth/login-by-sms
 * 短信验证码登录
 */
router.post('/login-by-sms', (req, res) => {
  const { phone, code } = req.body;
  
  if (!phone || !code) {
    return res.status(400).json({ code: 400, message: '请输入手机号和验证码' });
  }
  
  // 验证验证码
  const smsRecord = db.prepare(`
    SELECT * FROM sms_code 
    WHERE phone = ? AND code = ? AND used = 0 AND expire_time > datetime('now')
    ORDER BY created_at DESC LIMIT 1
  `).get(phone, code);
  
  if (!smsRecord) {
    return res.status(401).json({ code: 401, message: '验证码无效或已过期' });
  }
  
  // 标记验证码已使用
  db.prepare(`UPDATE sms_code SET used = 1 WHERE id = ?`).run(smsRecord.id);
  
  // 查找或创建用户
  let user = db.prepare(`SELECT * FROM user WHERE phone = ?`).get(phone);
  
  if (!user) {
    // 自动创建用户（根据需求可调整）
    const result = db.prepare(`
      INSERT INTO user (username, real_name, phone, password_hash, status, flag_contact)
      VALUES (?, ?, ?, ?, 1, 1)
    `).run(phone, phone, phone, bcrypt.hashSync('123456', 10));
    
    user = db.prepare(`SELECT * FROM user WHERE id = ?`).get(result.lastInsertRowid);
  }
  
  if (user.status === 0) {
    return res.status(403).json({ code: 403, message: '账号已被禁用' });
  }
  
  // 更新最后登录时间
  db.prepare(`UPDATE user SET last_login_time = CURRENT_TIMESTAMP WHERE id = ?`).run(user.id);
  
  // 生成 JWT
  const token = jwt.sign(
    { userId: user.id, username: user.username },
    JWT_SECRET,
    { expiresIn: JWT_EXPIRES_IN }
  );
  
  // 获取用户角色
  const roles = db.prepare(`
    SELECT r.code, r.name FROM role r
    JOIN user_role ur ON r.id = ur.role_id
    WHERE ur.user_id = ?
  `).all(user.id);
  
  res.json({
    code: 200,
    message: '登录成功',
    data: {
      token,
      user: {
        id: user.id,
        username: user.username,
        realName: user.real_name,
        phone: user.phone,
        deptId: user.dept_id,
        roles: roles.map(r => ({ code: r.code, name: r.name }))
      }
    }
  });
});

/**
 * GET /api/auth/me
 * 获取当前用户信息
 */
router.get('/me', (req, res) => {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ code: 401, message: '未登录' });
  }
  
  try {
    const token = authHeader.split(' ')[1];
    const decoded = jwt.verify(token, JWT_SECRET);
    
    const user = db.prepare(`
      SELECT u.*, d.name as dept_name 
      FROM user u 
      LEFT JOIN dept d ON u.dept_id = d.id 
      WHERE u.id = ?
    `).get(decoded.userId);
    
    if (!user) {
      return res.status(404).json({ code: 404, message: '用户不存在' });
    }
    
    const roles = db.prepare(`
      SELECT r.code, r.name FROM role r
      JOIN user_role ur ON r.id = ur.role_id
      WHERE ur.user_id = ?
    `).all(user.id);
    
    res.json({
      code: 200,
      data: {
        id: user.id,
        username: user.username,
        realName: user.real_name,
        phone: user.phone,
        email: user.email,
        deptId: user.dept_id,
        deptName: user.dept_name,
        position: user.position,
        roles: roles.map(r => ({ code: r.code, name: r.name }))
      }
    });
  } catch (err) {
    return res.status(401).json({ code: 401, message: '登录已过期' });
  }
});

/**
 * POST /api/auth/logout
 * 登出（客户端清除 token 即可）
 */
router.post('/logout', (req, res) => {
  res.json({ code: 200, message: '登出成功' });
});

module.exports = router;
