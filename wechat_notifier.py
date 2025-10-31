"""
企业微信机器人通知模块
负责发送交易变化通知到企业微信群
"""
import json
import logging
import requests
from typing import Dict, Any, List, Optional
from datetime import datetime


class WeChatNotifier:
    """企业微信通知器"""

    def __init__(self, webhook_url: str):
        """
        初始化企业微信通知器

        Args:
            webhook_url: 企业微信机器人webhook地址
        """
        self.webhook_url = webhook_url
        self.logger = logging.getLogger(__name__)

    def _get_model_link(self, model_id: str) -> str:
        """
        获取模型持仓页面链接

        Args:
            model_id: 模型ID

        Returns:
            模型持仓页面链接
        """
        return f"https://nof1.ai/models/{model_id}"

    def send_trade_notification(self, trades: List[Dict[str, Any]]) -> bool:
        """
        发送交易通知

        Args:
            trades: 交易变化列表

        Returns:
            发送成功返回True，失败返回False
        """
        if not trades:
            self.logger.info("无交易变化，跳过通知")
            return True

        try:
            # 按模型分组，每个模型发送一条通知
            trades_by_model = {}
            for trade in trades:
                model_id = trade.get('model_id', 'unknown')
                if model_id not in trades_by_model:
                    trades_by_model[model_id] = []
                trades_by_model[model_id].append(trade)

            # 为每个模型发送单独的通知
            all_success = True
            for model_id, model_trades in trades_by_model.items():
                content = self._generate_notification_content(model_id, model_trades)
                success = self._send_message(content)
                if not success:
                    all_success = False

            if all_success:
                self.logger.info(f"成功发送交易通知，共 {len(trades_by_model)} 个账户，包含 {len(trades)} 个交易变化")
            else:
                self.logger.error("部分交易通知发送失败")

            return all_success

        except Exception as e:
            self.logger.error(f"发送交易通知时发生错误: {e}")
            return False

    def _generate_notification_content(self, model_id: str, trades: List[Dict[str, Any]]) -> str:
        """
        生成通知内容（单个账户）

        Args:
            model_id: 模型ID
            trades: 该模型的交易变化列表

        Returns:
            格式化的通知内容
        """
        content_lines = [
            f"检测到 `{model_id}` 有 {len(trades)} 个交易变化:",
            ""
        ]

        # 生成每个交易的信息
        for trade in trades:
            trade_type = trade.get('type', 'unknown')
            symbol = trade.get('symbol', '')
            action = trade.get('action', '')
            message = trade.get('message', '')

            # 提取交易信息并格式化
            if trade_type == 'position_opened':
                # 新开仓格式：`DOGE 新开仓`: 买多 49103 (杠杆: 10x, 进入: 0.1784, 当前: 0.178415, 止盈: 0.196123, 止损: 0.169381)
                quantity = trade.get('quantity', 0)
                leverage = trade.get('leverage', 1)
                entry_price = trade.get('entry_price', 0)
                current_price = trade.get('current_price', 0)
                tp = trade.get('tp', 'N/A')
                sl = trade.get('sl', 'N/A')
                trade_label = f"{symbol} 新开仓"
                formatted_message = f"{action} {int(quantity)} (杠杆: {leverage}x, 进入: {entry_price}, 当前: {current_price}, 止盈: {tp}, 止损: {sl})"
                content_lines.append(f"• `{trade_label}`: {formatted_message}")
            elif trade_type == 'position_closed':
                # 平仓格式
                quantity = abs(trade.get('last_quantity', 0))
                leverage = trade.get('last_leverage', 1)
                entry_price = trade.get('last_entry_price', 0)
                current_price = trade.get('last_current_price', 0)
                tp = trade.get('tp', 'N/A')
                sl = trade.get('sl', 'N/A')
                direction = trade.get('direction', '')
                trade_label = f"{symbol} 已平仓"
                formatted_message = f"({direction} {int(quantity)}, 杠杆: {leverage}x, 进入: {entry_price}, 当前: {current_price}, 止盈: {tp}, 止损: {sl})"
                content_lines.append(f"• `{trade_label}`: {formatted_message}")
            elif trade_type == 'position_changed':
                # 持仓变化格式
                quantity_change = trade.get('quantity_change', 0)
                current_quantity = trade.get('current_quantity', 0)
                current_leverage = trade.get('current_leverage', 1)
                current_entry_price = trade.get('current_entry_price', 0)
                current_price = trade.get('current_price', 0)
                tp = trade.get('tp', 'N/A')
                sl = trade.get('sl', 'N/A')
                trade_label = f"{symbol} {action}"
                formatted_message = f"{int(quantity_change)} (杠杆: {current_leverage}x, 进入: {current_entry_price}, 当前: {current_price}, 止盈: {tp}, 止损: {sl})"
                content_lines.append(f"• `{trade_label}`: {formatted_message}")
            else:
                # 其他类型直接使用原始消息
                content_lines.append(f"• {message}")

        return "\n".join(content_lines)

    def _send_message(self, content: str) -> bool:
        """
        发送消息到企业微信群

        Args:
            content: 消息内容

        Returns:
            发送成功返回True，失败返回False
        """
        try:
            # 构建消息数据
            message_data = {
                "msgtype": "markdown",
                "markdown": {
                    "content": content
                }
            }

            # 发送请求（显式启用证书验证）
            response = requests.post(
                self.webhook_url,
                json=message_data,
                headers={'Content-Type': 'application/json'},
                timeout=10,
                verify=True
            )

            # 检查响应
            response.raise_for_status()
            result = response.json()

            if result.get('errcode') == 0:
                self.logger.info("企业微信消息发送成功")
                return True
            else:
                self.logger.error(
                    f"企业微信消息发送失败: {result.get('errmsg', '未知错误')}")
                return False

        except requests.exceptions.RequestException as e:
            self.logger.error(f"发送企业微信消息时网络错误: {e}")
            return False
        except Exception as e:
            self.logger.error(f"发送企业微信消息时发生未知错误: {e}")
            return False

    def send_test_message(self) -> bool:
        """
        发送测试消息

        Returns:
            发送成功返回True，失败返回False
        """
        try:
            test_content = (
                "🧪 **AI交易监控系统测试**\n\n"
                "✅ 系统运行正常\n"
                f"⏰ 测试时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n\n"
                "如果您收到此消息，说明通知功能配置正确！"
            )

            return self._send_message(test_content)

        except Exception as e:
            self.logger.error(f"发送测试消息时发生错误: {e}")
            return False
