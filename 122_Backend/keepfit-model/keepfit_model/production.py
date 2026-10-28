"""Private server configuration, Apple identity verification and persistent spend limits."""
import hashlib
import os
import secrets
import time
from datetime import datetime, timezone
from threading import Lock
import httpx
import jwt
from pydantic import Field
from fastapi import Request
from .cloud import CloudProvider, VENDORS
from .providers import ServiceError
from .schemas import StrictModel

class AppleLogin(StrictModel):
    identity_token: str = Field(min_length=20,max_length=10000)
    challenge_id: str = Field(min_length=10,max_length=100)

class AppleAuth:
    def __init__(self,store,audience):
        self.store,self.audience=store,audience
        self.jwks=None; self.loaded=0; self.lock=Lock()
    def keys(self):
        with self.lock:
            if self.jwks is None or time.time()-self.loaded>3600:
                try:
                    with httpx.Client(timeout=10,trust_env=False) as c:
                        r=c.get('https://appleid.apple.com/auth/keys');r.raise_for_status()
                        self.jwks=r.json()['keys'];self.loaded=time.time()
                except Exception:
                    raise ServiceError('apple_unavailable','暂时无法验证 Apple 登录，请稍后重试。',503) from None
            return self.jwks
    def challenge(self,ip):
        now=int(time.time()); id=secrets.token_urlsafe(24); nonce=secrets.token_urlsafe(32)
        with self.store.transaction() as db:
            # Bound unauthenticated work and clean expired challenges.
            db.execute("DELETE FROM objects WHERE kind='challenge' AND CAST(json_extract(body,'$.expires') AS INTEGER)<?",(now,))
            count=db.execute("SELECT count(*) FROM objects WHERE owner=? AND kind='challenge'",('ip:'+ip,)).fetchone()[0]
            if count>=10: raise ServiceError('login_limit','登录请求较多，请五分钟后重试。',429)
            self.store.put(db,'ip:'+ip,'challenge',{'id':id,'nonce':nonce,'expires':now+300})
        return {'id':id,'nonce':nonce}
    def login(self,body,ip):
        with self.store.transaction() as db:
            challenge=self.store.get(db,'ip:'+ip,'challenge',body.challenge_id)
        try:
            header=jwt.get_unverified_header(body.identity_token)
            if header.get('alg')!='RS256': raise ValueError()
            key=next(k for k in self.keys() if k['kid']==header.get('kid'))
            claims=jwt.decode(body.identity_token,jwt.PyJWK.from_dict(key).key,algorithms=['RS256'],
                              issuer='https://appleid.apple.com',audience=self.audience,
                              options={'require':['exp','iat','sub','iss','aud','nonce']})
            if challenge['expires']<time.time() or not secrets.compare_digest(claims['nonce'],challenge['nonce']): raise ValueError()
            owner='apple:'+hashlib.sha256(claims['sub'].encode()).hexdigest()
        except ServiceError: raise
        except Exception: raise ServiceError('apple_login_invalid','Apple 登录验证失败，请重新登录。',401) from None
        token=secrets.token_urlsafe(48); digest=hashlib.sha256(token.encode()).hexdigest(); expires=int(time.time())+86400
        with self.store.transaction() as db:
            # Consume once after cryptographic verification, atomically with session creation.
            self.store.get(db,'ip:'+ip,'challenge',body.challenge_id)
            db.execute("DELETE FROM objects WHERE owner=? AND kind='challenge' AND id=?",('ip:'+ip,body.challenge_id))
            db.execute("DELETE FROM objects WHERE kind='session' AND CAST(json_extract(body,'$.expires') AS INTEGER)<?",(int(time.time()),))
            self.store.put(db,'auth','session',{'id':digest,'owner':owner,'expires':expires})
        return {'token':token,'expires_at':expires}
    def owner(self,token):
        digest=hashlib.sha256(token.encode()).hexdigest()
        with self.store.transaction() as db:
            try: session=self.store.get(db,'auth','session',digest)
            except ServiceError: return None
        return session['owner'] if session['expires']>time.time() else None

class ServerRuntime:
    def __init__(self,store,vendor,key,per_user=10,global_limit=10,transport=None,key_path=None):
        if vendor not in VENDORS or (not key_path and len(key)<20): raise ValueError('Server provider configuration is missing')
        self.store,self.vendor,self._key=store,vendor,key
        self.key_path=key_path
        self.per_user,self.global_limit,self.transport=per_user,global_limit,transport
    def status(self,owner):
        return {'provider':self.vendor,'connected':bool(self.read_key()),'model':VENDORS[self.vendor]['model'],
                'calls_used':self.usage(owner),'call_limit':self.per_user,'tokens_used':0,'key_storage':'server_only'}
    def read_key(self):
        if self.key_path:
            if not self.key_path.exists(): return None
            if self.key_path.stat().st_mode & 0o077: return None
            value=self.key_path.read_text().strip()
            return value if len(value)>=20 and value.isascii() and not any(c.isspace() for c in value) else None
        return self._key
    def usage(self,owner):
        with self.store.transaction() as db:
            try: return self.store.get(db,owner,'quota',self.day())['calls']
            except ServiceError: return 0
    @staticmethod
    def day(): return datetime.now(timezone.utc).strftime('%Y-%m-%d')
    def provider(self,owner,rules,examples):
        key=self.read_key()
        if not key: raise ServiceError('provider_not_configured','饮食识别服务正在准备中，请稍后再试。',503)
        def reserve():
            with self.store.transaction() as db:
                for user,limit in [(owner,self.per_user),('server',self.global_limit)]:
                    try: current=self.store.get(db,user,'quota',self.day())
                    except ServiceError: current={'id':self.day(),'calls':0}
                    if current['calls']>=limit: raise ServiceError('daily_limit','今天的识别额度已用完，已有记录仍可查看。',429)
                    current['calls']+=1;self.store.put(db,user,'quota',current)
        return CloudProvider(self.vendor,key,rules,examples,reserve,lambda usage:None,self.transport)


def configure_server(store):
    from pathlib import Path
    key_path=Path(os.environ['KEEPFIT_PROVIDER_KEY_FILE'])
    return ServerRuntime(store,os.environ.get('KEEPFIT_CLOUD_PROVIDER','deepseek'),'',
                         int(os.environ.get('KEEPFIT_USER_DAILY_LIMIT','10')),int(os.environ.get('KEEPFIT_DAILY_LIMIT','10')),key_path=key_path)
