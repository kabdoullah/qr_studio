"""Comptes et QR Codes : users, qr_codes et une table de contenu par type.

Les tables existantes (files, business_cards, social_pages) restent gérées
par leur module et ne sont pas touchées.

Revision ID: 0001
Revises: 
Create Date: 2026-09-26 08:16:34.172907
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = '0001'
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table('users',
    sa.Column('id', sa.Uuid(), nullable=False),
    sa.Column('email', sa.String(length=254), nullable=False),
    sa.Column('password_hash', sa.String(length=255), nullable=False),
    sa.Column('first_name', sa.String(length=100), nullable=False),
    sa.Column('last_name', sa.String(length=100), nullable=False),
    sa.Column('is_active', sa.Boolean(), nullable=False),
    sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
    sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False),
    sa.PrimaryKeyConstraint('id'),
    sa.UniqueConstraint('email')
    )
    op.create_table('qr_codes',
    sa.Column('id', sa.Uuid(), nullable=False),
    sa.Column('user_id', sa.Uuid(), nullable=False),
    sa.Column('type', sa.String(length=20), nullable=False),
    sa.Column('slug', sa.String(length=32), nullable=False),
    sa.Column('title', sa.String(length=100), nullable=False),
    sa.Column('is_active', sa.Boolean(), nullable=False),
    sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
    sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False),
    sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('id'),
    sa.UniqueConstraint('slug')
    )
    with op.batch_alter_table('qr_codes', schema=None) as batch_op:
        batch_op.create_index(batch_op.f('ix_qr_codes_user_id'), ['user_id'], unique=False)

    op.create_table('business_card_profiles',
    sa.Column('qr_code_id', sa.Uuid(), nullable=False),
    sa.Column('mode', sa.String(length=10), nullable=False),
    sa.Column('file_id', sa.String(length=32), nullable=True),
    sa.Column('first_name', sa.String(length=200), nullable=False),
    sa.Column('last_name', sa.String(length=200), nullable=False),
    sa.Column('job_title', sa.String(length=200), nullable=False),
    sa.Column('company', sa.String(length=200), nullable=False),
    sa.Column('phone', sa.String(length=200), nullable=False),
    sa.Column('email', sa.String(length=200), nullable=False),
    sa.Column('website', sa.String(length=200), nullable=False),
    sa.Column('address', sa.String(length=200), nullable=False),
    sa.Column('city', sa.String(length=200), nullable=False),
    sa.Column('country', sa.String(length=200), nullable=False),
    sa.Column('linkedin', sa.String(length=200), nullable=False),
    sa.Column('instagram', sa.String(length=200), nullable=False),
    sa.Column('whatsapp', sa.String(length=200), nullable=False),
    sa.ForeignKeyConstraint(['qr_code_id'], ['qr_codes.id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('qr_code_id')
    )
    op.create_table('cv_documents',
    sa.Column('qr_code_id', sa.Uuid(), nullable=False),
    sa.Column('file_id', sa.String(length=32), nullable=False),
    sa.Column('filename', sa.String(length=200), nullable=False),
    sa.ForeignKeyConstraint(['qr_code_id'], ['qr_codes.id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('qr_code_id')
    )
    op.create_table('social_media_profiles',
    sa.Column('id', sa.Uuid(), nullable=False),
    sa.Column('qr_code_id', sa.Uuid(), nullable=False),
    sa.Column('description', sa.String(length=300), nullable=False),
    sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
    sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False),
    sa.ForeignKeyConstraint(['qr_code_id'], ['qr_codes.id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('id'),
    sa.UniqueConstraint('qr_code_id')
    )
    op.create_table('texts',
    sa.Column('qr_code_id', sa.Uuid(), nullable=False),
    sa.Column('content', sa.Text(), nullable=False),
    sa.ForeignKeyConstraint(['qr_code_id'], ['qr_codes.id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('qr_code_id')
    )
    op.create_table('websites',
    sa.Column('qr_code_id', sa.Uuid(), nullable=False),
    sa.Column('url', sa.String(length=500), nullable=False),
    sa.ForeignKeyConstraint(['qr_code_id'], ['qr_codes.id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('qr_code_id')
    )
    op.create_table('wifi_profiles',
    sa.Column('qr_code_id', sa.Uuid(), nullable=False),
    sa.Column('ssid', sa.String(length=64), nullable=False),
    sa.Column('password', sa.String(length=128), nullable=False),
    sa.Column('security', sa.String(length=8), nullable=False),
    sa.Column('hidden', sa.Boolean(), nullable=False),
    sa.ForeignKeyConstraint(['qr_code_id'], ['qr_codes.id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('qr_code_id')
    )
    op.create_table('social_media_links',
    sa.Column('id', sa.Uuid(), nullable=False),
    sa.Column('profile_id', sa.Uuid(), nullable=False),
    sa.Column('platform', sa.String(length=32), nullable=False),
    sa.Column('url', sa.String(length=500), nullable=False),
    sa.Column('label', sa.String(length=50), nullable=False),
    sa.Column('display_order', sa.Integer(), nullable=False),
    sa.Column('is_visible', sa.Boolean(), nullable=False),
    sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
    sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False),
    sa.ForeignKeyConstraint(['profile_id'], ['social_media_profiles.id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('id')
    )
    with op.batch_alter_table('social_media_links', schema=None) as batch_op:
        batch_op.create_index(batch_op.f('ix_social_media_links_profile_id'), ['profile_id'], unique=False)



def downgrade() -> None:
    with op.batch_alter_table('social_media_links', schema=None) as batch_op:
        batch_op.drop_index(batch_op.f('ix_social_media_links_profile_id'))

    op.drop_table('social_media_links')
    op.drop_table('wifi_profiles')
    op.drop_table('websites')
    op.drop_table('texts')
    op.drop_table('social_media_profiles')
    op.drop_table('cv_documents')
    op.drop_table('business_card_profiles')
    with op.batch_alter_table('qr_codes', schema=None) as batch_op:
        batch_op.drop_index(batch_op.f('ix_qr_codes_user_id'))

    op.drop_table('qr_codes')
    op.drop_table('users')
