const express = require('express');
const router = express.Router();
const db = require('better-sqlite3')(require('path').join(__dirname, '..', 'data', 'oa.db'));
const bcrypt = require('bcryptjs');
const { authMiddleware, checkPermission } = require('../middleware/auth');

// 所有路由需要认证
router.use(authMiddleware);

// 获取用户列表
router.get('/', checkPermission('user:view'), (req, res) => {
  try {
    const { page = 1, pageSize = 20, deptId, status, keyword, roleId } = req.query;
    const offset = (parseInt(page) - 1) * parseInt(pageSize);
    
    let sql = `
      SELECT u.id, u.username, u.real_name, u.phone, u.email, u.dept_id, u.position, 
             u.status, u.flag_contact, u.last_login_time, u.created_at,
             d.name as dept_name
      FROM user u
      LEFT JOIN dept d ON u.dept_id = d.id
      WHERE 1=1
    `;
    const params = [];
    
    if (deptId) {
      sql += ' AND u.dept_id = ?';
      params.push(deptId);
    }
    
    if (status !== undefined && status !== '') {
      sql += ' AND u.status = ?';
      params.push(parseInt(status));
    }
    
    if (keyword) {
      sql += ' AND (u.username LIKE ? OR u.real_name LIKE ? OR u.phone LIKE ?)';
      const likeKeyword = `%${keyword}%`;
      params.push(likeKeyword, likeKeyword, likeKeyword);
    }
    
    if (roleId) {
      sql += ' AND EXISTS (SELECT 1 FROM user_role ur WHERE ur.user_id = u.id AND ur.role_id = ?)';
      params.push(roleId);
    }
    
    // 获取总数
    const countSql = sql.replace(/SELECT.*FROM/, 'SELECT COUNT(*) as total FROM');
    const countResult = db.prepare(countSql).get(...params);
    const total = countResult ? countResult.total : 0;
    
    // 排序和分页
    sql += ' ORDER BY u.created_at DESC LIMIT ? OFFSET ?';
    params.push(parseInt(pageSize), offset);
    
    const users = db.prepare(sql).all(...params);
    
    // 获取每个用户的角色
    const usersWithRoles = users.map(user => {
      const roles = db.prepare(`
        SELECT r.id, r.code, r.name 
        FROM role r
        JOIN user_role ur ON r.id = ur.role_id
        WHERE ur.user_id = ?
      `).all(user.id);
      
      return {
        ...user,
        roles
      };
    });
    
    res.json({
      success: true,
      data: usersWithRoles,
      pagination: {
        page: parseInt(page),
        pageSize: parseInt(pageSize),
        total
      }
    });
  } catch (error) {
    console.error('获取用户列表失败:', error);
    res.status(500).json({
      success: false,
      message: '获取用户列表失败'
    });
  }
});

// 获取单个用户
router.get('/:id', checkPermission('user:view'), (req, res) => {
  try {
    const { id } = req.params;
    
    const user = db.prepare(`
      SELECT u.id, u.username, u.real_name, u.phone, u.email, u.dept_id, u.position,
             u.status, u.flag_contact, u.last_login_time, u.created_at, u.updated_at,
             d.name as dept_name
      FROM user u
      LEFT JOIN dept d ON u.dept_id = d.id
      WHERE u.id = ?
    `).get(id);
    
    if (!user) {
      return res.status(404).json({
        success: false,
        message: '用户不存在'
      });
    }
    
    // 获取用户角色
    const roles = db.prepare(`
      SELECT r.id, r.code, r.name 
      FROM role r
      JOIN user_role ur ON r.id = ur.role_id
      WHERE ur.user_id = ?
    `).all(id);
    
    res.json({
      success: true,
      data: {
        ...user,
        roles
      }
    });
  } catch (error) {
    console.error('获取用户详情失败:', error);
    res.status(500).json({
      success: false,
      message: '获取用户详情失败'
    });
  }
});

// 新增用户
router.post('/', checkPermission('user:create'), (req, res) => {
  try {
    const { username, real_name, phone, email, dept_id, position, roleIds = [] } = req.body;
    
    // 检查用户名是否存在
    const existingUser = db.prepare('SELECT id FROM user WHERE username = ?').get(username);
    if (existingUser) {
      return res.status(400).json({
        success: false,
        message: '用户名已存在'
      });
    }
    
    // 检查手机号是否存在
    if (phone) {
      const existingPhone = db.prepare('SELECT id FROM user WHERE phone = ?').get(phone);
      if (existingPhone) {
        return res.status(400).json({
          success: false,
          message: '手机号已被使用'
        });
      }
    }
    
    // 生成随机密码
    const generatePassword = () => {
      const chars = 'ABCDEFGHJKMNPQRSTWXYZabcdefhijkmnprstwxyz2345678';
      let password = '';
      for (let i = 0; i < 8; i++) {
        password += chars.charAt(Math.floor(Math.random() * chars.length));
      }
      return password;
    };
    
    const plainPassword = generatePassword();
    const password_hash = bcrypt.hashSync(plainPassword, 10);
    
    // 插入用户
    const result = db.prepare(`
      INSERT INTO user (username, real_name, phone, email, dept_id, position, password_hash, status, flag_contact)
      VALUES (?, ?, ?, ?, ?, ?, ?, 1, 1)
    `).run(username, real_name, phone, email, dept_id, position, password_hash);
    
    const userId = result.lastInsertRowid;
    
    // 分配角色
    if (roleIds.length > 0) {
      const insertRole = db.prepare('INSERT INTO user_role (user_id, role_id) VALUES (?, ?)');
      roleIds.forEach(roleId => {
        insertRole.run(userId, roleId);
      });
    }
    
    res.json({
      success: true,
      message: '用户创建成功',
      data: {
        id: userId,
        username,
        plainPassword // 返回明文密码，用于通知用户
      }
    });
  } catch (error) {
    console.error('创建用户失败:', error);
    res.status(500).json({
      success: false,
      message: '创建用户失败'
    });
  }
});

// 编辑用户
router.put('/:id', checkPermission('user:edit'), (req, res) => {
  try {
    const { id } = req.params;
    const { real_name, phone, email, dept_id, position, roleIds } = req.body;
    
    // 检查用户是否存在
    const user = db.prepare('SELECT id FROM user WHERE id = ?').get(id);
    if (!user) {
      return res.status(404).json({
        success: false,
        message: '用户不存在'
      });
    }
    
    // 检查手机号是否被其他用户使用
    if (phone) {
      const existingPhone = db.prepare('SELECT id FROM user WHERE phone = ? AND id != ?').get(phone, id);
      if (existingPhone) {
        return res.status(400).json({
          success: false,
          message: '手机号已被其他用户使用'
        });
      }
    }
    
    // 更新用户信息
    db.prepare(`
      UPDATE user 
      SET real_name = COALESCE(?, real_name),
          phone = COALESCE(?, phone),
          email = COALESCE(?, email),
          dept_id = COALESCE(?, dept_id),
          position = COALESCE(?, position),
          updated_at = CURRENT_TIMESTAMP
      WHERE id = ?
    `).run(real_name, phone, email, dept_id, position, id);
    
    // 更新角色
    if (roleIds !== undefined) {
      // 删除现有角色
      db.prepare('DELETE FROM user_role WHERE user_id = ?').run(id);
      
      // 添加新角色
      if (roleIds.length > 0) {
        const insertRole = db.prepare('INSERT INTO user_role (user_id, role_id) VALUES (?, ?)');
        roleIds.forEach(roleId => {
          insertRole.run(id, roleId);
        });
      }
    }
    
    res.json({
      success: true,
      message: '用户更新成功'
    });
  } catch (error) {
    console.error('更新用户失败:', error);
    res.status(500).json({
      success: false,
      message: '更新用户失败'
    });
  }
});

// 修改用户状态
router.patch('/:id/status', checkPermission('user:edit'), (req, res) => {
  try {
    const { id } = req.params;
    const { status } = req.body;
    
    // 检查用户是否存在
    const user = db.prepare('SELECT id, username FROM user WHERE id = ?').get(id);
    if (!user) {
      return res.status(404).json({
        success: false,
        message: '用户不存在'
      });
    }
    
    // 更新状态
    db.prepare(`
      UPDATE user 
      SET status = ?, 
          flag_contact = ?, 
          updated_at = CURRENT_TIMESTAMP 
      WHERE id = ?
    `).run(status, status, id);
    
    res.json({
      success: true,
      message: status === 1 ? '用户已启用' : '用户已禁用'
    });
  } catch (error) {
    console.error('修改用户状态失败:', error);
    res.status(500).json({
      success: false,
      message: '修改用户状态失败'
    });
  }
});

// 重置密码
router.post('/:id/reset-password', checkPermission('user:edit'), (req, res) => {
  try {
    const { id } = req.params;
    
    // 检查用户是否存在
    const user = db.prepare('SELECT id, username, phone FROM user WHERE id = ?').get(id);
    if (!user) {
      return res.status(404).json({
        success: false,
        message: '用户不存在'
      });
    }
    
    // 生成新密码
    const generatePassword = () => {
      const chars = 'ABCDEFGHJKMNPQRSTWXYZabcdefhijkmnprstwxyz2345678';
      let password = '';
      for (let i = 0; i < 8; i++) {
        password += chars.charAt(Math.floor(Math.random() * chars.length));
      }
      return password;
    };
    
    const plainPassword = generatePassword();
    const password_hash = bcrypt.hashSync(plainPassword, 10);
    
    // 更新密码
    db.prepare('UPDATE user SET password_hash = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?').run(password_hash, id);
    
    // 重置登录失败计数
    db.prepare('UPDATE user SET login_attempts = 0, lock_until = NULL WHERE id = ?').run(id);
    
    res.json({
      success: true,
      message: '密码已重置',
      data: {
        plainPassword // 返回明文密码
      }
    });
  } catch (error) {
    console.error('重置密码失败:', error);
    res.status(500).json({
      success: false,
      message: '重置密码失败'
    });
  }
});

// 删除用户（软删除，设置status=0）
router.delete('/:id', checkPermission('user:delete'), (req, res) => {
  try {
    const { id } = req.params;
    
    // 检查用户是否存在
    const user = db.prepare('SELECT id, username FROM user WHERE id = ?').get(id);
    if (!user) {
      return res.status(404).json({
        success: false,
        message: '用户不存在'
      });
    }
    
    // 不允许删除admin用户
    if (user.username === 'admin') {
      return res.status(400).json({
        success: false,
        message: '不能删除管理员账号'
      });
    }
    
    // 软删除
    db.prepare('UPDATE user SET status = 0, flag_contact = 0, updated_at = CURRENT_TIMESTAMP WHERE id = ?').run(id);
    
    res.json({
      success: true,
      message: '用户已删除'
    });
  } catch (error) {
    console.error('删除用户失败:', error);
    res.status(500).json({
      success: false,
      message: '删除用户失败'
    });
  }
});

module.exports = router;
