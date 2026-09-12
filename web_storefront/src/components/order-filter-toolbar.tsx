"use client";

import { Calendar, Filter, RotateCcw, Search, SlidersHorizontal, X } from "lucide-react";
import React from "react";

export type OrderStatusFilter = "all" | "active" | "completed" | "postponed" | "canceled";
export type TimeframeFilter = "all" | "today" | "week" | "month" | "three_months";
export type SortOrder = "newest" | "oldest" | "highest_price";

export interface FilterOptionCounts {
  all: number;
  active: number;
  completed: number;
  postponed: number;
  canceled: number;
}

interface OrderFilterToolbarProps {
  statusFilter: OrderStatusFilter;
  onStatusChange: (status: OrderStatusFilter) => void;
  counts: FilterOptionCounts;
  searchQuery: string;
  onSearchChange: (query: string) => void;
  searchPlaceholder?: string;
  timeframe: TimeframeFilter;
  onTimeframeChange: (tf: TimeframeFilter) => void;
  sortOrder: SortOrder;
  onSortChange: (sort: SortOrder) => void;
  onReset: () => void;
  totalFilteredCount: number;
  totalOriginalCount: number;
  summaryStats?: {
    totalSales?: number;
    totalCommission?: number;
    deliveredCount?: number;
    canceledCount?: number;
  };
}

const statusTabs: { id: OrderStatusFilter; label: string }[] = [
  { id: "all", label: "الكل" },
  { id: "active", label: "النشطة" },
  { id: "completed", label: "المكتملة" },
  { id: "postponed", label: "المؤجلة" },
  { id: "canceled", label: "الملغية والمرتجعة" },
];

export function OrderFilterToolbar({
  statusFilter,
  onStatusChange,
  counts,
  searchQuery,
  onSearchChange,
  searchPlaceholder = "بحث برقم الطلب أو اسم القطعة...",
  timeframe,
  onTimeframeChange,
  sortOrder,
  onSortChange,
  onReset,
  totalFilteredCount,
  totalOriginalCount,
  summaryStats,
}: OrderFilterToolbarProps) {
  const isFiltered =
    statusFilter !== "all" ||
    searchQuery.trim() !== "" ||
    timeframe !== "all" ||
    sortOrder !== "newest";

  return (
    <div className="order-filter-toolbar">
      {/* 1. Quick Status Pill Tabs with Badges */}
      <div className="status-pill-tabs" role="tablist">
        {statusTabs.map((tab) => {
          const count = counts[tab.id] ?? 0;
          const isActive = statusFilter === tab.id;
          return (
            <button
              key={tab.id}
              type="button"
              role="tab"
              aria-selected={isActive}
              className={`status-pill-btn ${isActive ? "active" : ""}`}
              onClick={() => onStatusChange(tab.id)}
            >
              <span>{tab.label}</span>
              <span className="status-pill-badge">{count}</span>
            </button>
          );
        })}
      </div>

      {/* 2. Search & Fine Controls Row */}
      <div className="filter-controls-row">
        {/* Search Input */}
        <div className="filter-search-box">
          <Search className="search-icon" />
          <input
            type="text"
            value={searchQuery}
            onChange={(e) => onSearchChange(e.target.value)}
            placeholder={searchPlaceholder}
          />
          {searchQuery && (
            <button
              type="button"
              className="search-clear-btn"
              onClick={() => onSearchChange("")}
              aria-label="مسح البحث"
            >
              <X />
            </button>
          )}
        </div>

        {/* Timeframe Dropdown */}
        <div className="filter-select-wrap">
          <Calendar className="select-icon" />
          <select
            value={timeframe}
            onChange={(e) => onTimeframeChange(e.target.value as TimeframeFilter)}
            aria-label="تصفية حسب التاريخ"
          >
            <option value="all">كل الأوقات</option>
            <option value="today">اليوم</option>
            <option value="week">آخر 7 أيام</option>
            <option value="month">هذا الشهر</option>
            <option value="three_months">آخر 3 أشهر</option>
          </select>
        </div>

        {/* Sort Dropdown */}
        <div className="filter-select-wrap">
          <SlidersHorizontal className="select-icon" />
          <select
            value={sortOrder}
            onChange={(e) => onSortChange(e.target.value as SortOrder)}
            aria-label="ترتيب الطلبات"
          >
            <option value="newest">الأحدث أولاً</option>
            <option value="oldest">الأقدم أولاً</option>
            <option value="highest_price">الأعلى قيمة</option>
          </select>
        </div>

        {/* Reset Button */}
        {isFiltered && (
          <button
            type="button"
            className="filter-reset-btn"
            onClick={onReset}
            title="إلغاء جميع الفلاتر"
          >
            <RotateCcw />
            <span>إعادة ضبط</span>
          </button>
        )}
      </div>

      {/* 3. Dynamic Stats Strip (if filtered or requested) */}
      {summaryStats && (
        <div className="filtered-summary-strip">
          <div className="summary-stat-pill">
            <small>الطلبات المعروضة</small>
            <strong>{totalFilteredCount} طلب</strong>
          </div>
          {summaryStats.totalSales !== undefined && (
            <div className="summary-stat-pill">
              <small>إجمالي المبيعات</small>
              <strong>{summaryStats.totalSales.toFixed(2)} د.ل</strong>
            </div>
          )}
          {summaryStats.totalCommission !== undefined && (
            <div className="summary-stat-pill earned-pill">
              <small>أرباحك المعتمدة</small>
              <strong>{summaryStats.totalCommission.toFixed(2)} د.ل</strong>
            </div>
          )}
          {summaryStats.deliveredCount !== undefined && (
            <div className="summary-stat-pill">
              <small>المسلّمة</small>
              <strong>{summaryStats.deliveredCount}</strong>
            </div>
          )}
        </div>
      )}
    </div>
  );
}
