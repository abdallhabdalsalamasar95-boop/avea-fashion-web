import { CartItem } from "@/lib/types";

export type CommissionConfig = {
  defaultPercent: number;
  perProductEnabled: boolean;
};

type CommissionLine = Pick<CartItem, "price" | "quantity" | "commissionPercent">;

export const defaultCommissionConfig: CommissionConfig = {
  defaultPercent: 7,
  perProductEnabled: true,
};

export function commissionRate(
  item: Pick<CommissionLine, "commissionPercent">,
  config: CommissionConfig,
): number {
  const productRate = Number(item.commissionPercent ?? 0);
  const rate = config.perProductEnabled && productRate > 0
    ? productRate
    : Number(config.defaultPercent ?? 0);
  return Math.min(100, Math.max(0, rate));
}

export function lineCommission(item: CommissionLine, config: CommissionConfig): number {
  return Math.max(0, Number(item.price) || 0)
    * Math.max(0, Number(item.quantity) || 0)
    * commissionRate(item, config)
    / 100;
}

export function totalCommission(items: CommissionLine[], config: CommissionConfig): number {
  return items.reduce((sum, item) => sum + lineCommission(item, config), 0);
}
