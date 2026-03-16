#!/usr/bin/env python3
"""
Risk Manager - 风控模块
包含: 仓位限制、止损、熔断、API限流保护
"""

import asyncio
import logging
from datetime import datetime, timedelta
from typing import Optional, Dict, Any
from dataclasses import dataclass
import yaml


@dataclass
class RiskCheckResult:
    """风控检查结果"""
    passed: bool
    reason: Optional[str] = None
    action: Optional[str] = None


class RiskManager:
    """风控管理器"""
    
    def __init__(self, config_path: str = "config.yaml"):
        with open(config_path, 'r') as f:
            config = yaml.safe_load(f)
            
        self.risk_config = config['risk_management']
        self.runtime_config = config['runtime']
        
        # 状态跟踪
        self.consecutive_errors = 0
        self.circuit_breaker_active = False
        self.cooldown_until: Optional[datetime] = None
        self.last_request_time: Optional[datetime] = None
        self.request_count = 0
        self.request_window_start: Optional[datetime] = None
        
        # 价格历史 (用于波动率计算)
        self.price_history: list = []
        self.max_price_history = 100
        
        # 持仓跟踪
        self.initial_balance: Optional[float] = None
        self.peak_balance: Optional[float] = None
        self.current_drawdown = 0.0
        
        self.logger = logging.getLogger(__name__)
        
    # ═══════════════════════════════════════════
    # 仓位限制检查
    # ═══════════════════════════════════════════
    
    def check_position_limits(
        self, 
        current_position_value: float, 
        total_balance: float,
        current_layers: int,
        side: str
    ) -> RiskCheckResult:
        """检查仓位限制"""
        
        # 1. 总仓位比例检查
        max_ratio = self.risk_config['position_limits']['max_position_ratio']
        current_ratio = current_position_value / total_balance if total_balance > 0 else 0
        
        if current_ratio >= max_ratio:
            return RiskCheckResult(
                passed=False,
                reason=f"仓位比例 {current_ratio:.2%} 超过限制 {max_ratio:.2%}",
                action="停止开仓"
            )
            
        # 2. 网格层数检查
        max_layers = self.risk_config['position_limits']['max_long_layers'] if side == 'long' else self.risk_config['position_limits']['max_short_layers']
        
        if current_layers >= max_layers:
            return RiskCheckResult(
                passed=False,
                reason=f"{side} 方向层数 {current_layers} 超过限制 {max_layers}",
                action="停止该方向开仓"
            )
            
        return RiskCheckResult(passed=True)
        
    # ═══════════════════════════════════════════
    # 止损检查
    # ═══════════════════════════════════════════
    
    def check_stop_loss(
        self,
        current_balance: float,
        open_positions: list
    ) -> RiskCheckResult:
        """检查止损条件"""
        
        # 初始化峰值余额
        if self.initial_balance is None:
            self.initial_balance = current_balance
            self.peak_balance = current_balance
            
        # 更新峰值
        if current_balance > self.peak_balance:
            self.peak_balance = current_balance
            
        # 计算回撤
        self.current_drawdown = (self.peak_balance - current_balance) / self.peak_balance
        
        # 1. 总资金回撤止损
        max_drawdown = self.risk_config['stop_loss']['max_drawdown']
        if self.current_drawdown >= max_drawdown:
            return RiskCheckResult(
                passed=False,
                reason=f"总资金回撤 {self.current_drawdown:.2%} 超过限制 {max_drawdown:.2%}",
                action="全部平仓，停止交易"
            )
            
        # 2. 单笔止损检查
        grid_stop = self.risk_config['stop_loss']['grid_stop_loss']
        for pos in open_positions:
            if pos.get('unrealized_pnl', 0) / pos.get('cost', 1) <= -grid_stop:
                return RiskCheckResult(
                    passed=False,
                    reason=f"单笔网格亏损超过 {grid_stop:.2%}",
                    action=f"平掉网格 {pos.get('level')}"
                )
                
        return RiskCheckResult(passed=True)
        
    def check_trailing_stop(
        self,
        current_price: float,
        entry_price: float,
        highest_price: float
    ) -> RiskCheckResult:
        """检查追踪止损"""
        if not self.risk_config['stop_loss']['trailing_stop']:
            return RiskCheckResult(passed=True)
            
        trailing_distance = self.risk_config['stop_loss']['trailing_distance']
        
        # 价格从最高点回落超过追踪距离
        if highest_price > 0:
            pullback = (highest_price - current_price) / highest_price
            if pullback >= trailing_distance:
                return RiskCheckResult(
                    passed=False,
                    reason=f"价格从高点 {highest_price:.2f} 回落 {pullback:.2%}，超过追踪止损 {trailing_distance:.2%}",
                    action="触发追踪止损，平仓"
                )
                
        return RiskCheckResult(passed=True)
        
    # ═══════════════════════════════════════════
    # 熔断机制
    # ═══════════════════════════════════════════
    
    def check_circuit_breaker(self, error_occurred: bool = False) -> RiskCheckResult:
        """检查熔断条件"""
        
        # 1. 检查是否在冷却期
        if self.cooldown_until and datetime.now() < self.cooldown_until:
            remaining = (self.cooldown_until - datetime.now()).seconds
            return RiskCheckResult(
                passed=False,
                reason=f"熔断冷却中，剩余 {remaining} 秒",
                action="暂停交易"
            )
            
        # 2. 连续错误熔断
        if error_occurred:
            self.consecutive_errors += 1
            max_errors = self.risk_config['circuit_breaker']['max_consecutive_errors']
            
            if self.consecutive_errors >= max_errors:
                self.activate_circuit_breaker()
                return RiskCheckResult(
                    passed=False,
                    reason=f"连续错误 {self.consecutive_errors} 次，触发熔断",
                    action="停止交易，进入冷却"
                )
        else:
            # 成功则重置错误计数
            self.consecutive_errors = 0
            
        return RiskCheckResult(passed=True)
        
    def activate_circuit_breaker(self):
        """激活熔断"""
        self.circuit_breaker_active = True
        cooldown_seconds = self.risk_config['circuit_breaker']['cooldown_seconds']
        self.cooldown_until = datetime.now() + timedelta(seconds=cooldown_seconds)
        self.logger.warning(f"🔒 熔断已激活，冷却时间: {cooldown_seconds} 秒")
        
    def reset_circuit_breaker(self):
        """重置熔断"""
        self.circuit_breaker_active = False
        self.cooldown_until = None
        self.consecutive_errors = 0
        self.logger.info("🔓 熔断已重置")
        
    def check_price_volatility(self, current_price: float) -> RiskCheckResult:
        """检查价格波动熔断"""
        self.price_history.append({
            'price': current_price,
            'time': datetime.now()
        })
        
        # 保持历史记录在限制内
        if len(self.price_history) > self.max_price_history:
            self.price_history = self.price_history[-self.max_price_history:]
            
        # 计算5分钟内的波动
        threshold = self.risk_config['circuit_breaker']['price_volatility_threshold']
        cutoff_time = datetime.now() - timedelta(minutes=5)
        
        recent_prices = [
            p['price'] for p in self.price_history 
            if p['time'] > cutoff_time
        ]
        
        if len(recent_prices) >= 2:
            max_price = max(recent_prices)
            min_price = min(recent_prices)
            volatility = (max_price - min_price) / min_price
            
            if volatility >= threshold:
                self.activate_circuit_breaker()
                return RiskCheckResult(
                    passed=False,
                    reason=f"5分钟内价格波动 {volatility:.2%} 超过阈值 {threshold:.2%}",
                    action="触发熔断，暂停交易"
                )
                
        return RiskCheckResult(passed=True)
        
    # ═══════════════════════════════════════════
    # API 限流保护
    # ═══════════════════════════════════════════
    
    async def rate_limit_check(self) -> RiskCheckResult:
        """检查 API 限流"""
        now = datetime.now()
        max_requests = self.risk_config['rate_limit']['max_requests_per_minute']
        
        # 初始化时间窗口
        if self.request_window_start is None:
            self.request_window_start = now
            
        # 检查是否进入新的分钟
        if (now - self.request_window_start).seconds >= 60:
            self.request_window_start = now
            self.request_count = 0
            
        # 检查是否超过限制
        if self.request_count >= max_requests:
            backoff = self.risk_config['rate_limit']['backoff_seconds']
            self.logger.warning(f"⏳ API 限流，退避 {backoff} 秒")
            await asyncio.sleep(backoff)
            return RiskCheckResult(
                passed=False,
                reason="API 请求超过频率限制",
                action=f"退避 {backoff} 秒"
            )
            
        self.request_count += 1
        return RiskCheckResult(passed=True)
        
    def record_request(self):
        """记录一次 API 请求"""
        self.last_request_time = datetime.now()
        
    # ═══════════════════════════════════════════
    # 综合风控检查
    # ═══════════════════════════════════════════
    
    async def comprehensive_check(
        self,
        context: Dict[str, Any]
    ) -> RiskCheckResult:
        """综合风控检查"""
        
        # 1. 熔断检查
        result = self.check_circuit_breaker()
        if not result.passed:
            return result
            
        # 2. API 限流检查
        result = await self.rate_limit_check()
        if not result.passed:
            return result
            
        # 3. 仓位限制
        if 'position_value' in context and 'total_balance' in context:
            result = self.check_position_limits(
                context['position_value'],
                context['total_balance'],
                context.get('current_layers', 0),
                context.get('side', 'long')
            )
            if not result.passed:
                return result
                
        # 4. 止损检查
        if 'current_balance' in context:
            result = self.check_stop_loss(
                context['current_balance'],
                context.get('open_positions', [])
            )
            if not result.passed:
                return result
                
        # 5. 价格波动检查
        if 'current_price' in context:
            result = self.check_price_volatility(context['current_price'])
            if not result.passed:
                return result
                
        return RiskCheckResult(passed=True)
        
    def get_status(self) -> Dict[str, Any]:
        """获取风控状态"""
        return {
            'consecutive_errors': self.consecutive_errors,
            'circuit_breaker_active': self.circuit_breaker_active,
            'cooldown_until': self.cooldown_until.isoformat() if self.cooldown_until else None,
            'current_drawdown': self.current_drawdown,
            'request_count': self.request_count,
            'price_history_length': len(self.price_history)
        }


# ═══════════════════════════════════════════
# 测试
# ═══════════════════════════════════════════

if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    
    async def test():
        rm = RiskManager()
        
        # 测试仓位限制
        result = rm.check_position_limits(600, 1000, 3, 'long')
        print(f"仓位检查: {result}")
        
        # 测试止损
        result = rm.check_stop_loss(950, [])
        print(f"止损检查: {result}")
        print(f"当前回撤: {rm.current_drawdown:.2%}")
        
        # 测试熔断
        for i in range(6):
            result = rm.check_circuit_breaker(error_occurred=True)
            print(f"第 {i+1} 次错误: {result.passed}")
            
        print(f"熔断状态: {rm.circuit_breaker_active}")
        
    asyncio.run(test())
