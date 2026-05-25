from sqlalchemy import Column, Date, DateTime, Float, ForeignKey, Integer, String, UniqueConstraint, func
from sqlalchemy.orm import relationship

from app.db import Base


class FredSeries(Base):
    __tablename__ = "fred_series"

    id = Column(Integer, primary_key=True, index=True)
    series_id = Column(String(64), unique=True, nullable=False, index=True)
    title = Column(String(512), nullable=False)
    frequency = Column(String(128))
    units = Column(String(128))
    source = Column(String(128), nullable=False, default="FRED")
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    observations = relationship("MacroData", back_populates="series")


class MacroData(Base):
    __tablename__ = "macro_data"
    __table_args__ = (
        UniqueConstraint("series_id", "date", name="uq_macro_data_series_id_date"),
    )

    id = Column(Integer, primary_key=True, index=True)
    series_id = Column(String(64), ForeignKey("fred_series.series_id"), nullable=False, index=True)
    date = Column(Date, nullable=False, index=True)
    value = Column(Float)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    series = relationship("FredSeries", back_populates="observations")
