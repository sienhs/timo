"""Emit fixtures for an EMPTY timo_loadtest database only."""
import os

password_hash = os.environ['PASSWORD_HASH']
users = int(os.environ.get('LOADTEST_USERS', '10000'))
if not 1 <= users <= 10000:
    raise ValueError('LOADTEST_USERS must be between 1 and 10000')
assert password_hash.startswith('$2') and "'" not in password_hash
print(f"INSERT INTO venue VALUES (1,'loadtest','test',{users},NOW(6),NOW(6));")
print("INSERT INTO artist VALUES (1,'loadtest',NULL,NOW(6),NOW(6));")
print("INSERT INTO concert (concert_id,title,genre,age_rating,status,view_count,start_date,end_date,open_at,venue_id,created_at,updated_at) VALUES (1,'loadtest','CONCERT','ALL','ON_SALE',0,DATE_ADD(NOW(),INTERVAL 30 DAY),DATE_ADD(NOW(),INTERVAL 31 DAY),DATE_SUB(NOW(),INTERVAL 1 DAY),1,NOW(6),NOW(6));")
print("INSERT INTO concert_artist VALUES (1,1,1,NOW(6),NOW(6));")
for section in range(1, (users + 99) // 100 + 1):
    print(f"INSERT INTO section VALUES ({section},'S{section}','COMMON',10000,100,10,10,1,NOW(6),NOW(6));")
for i in range(1, users + 1):
    print(f"INSERT INTO member VALUES ({i},'USER','019{i:08d}','ACTIVE','loadtest{i}','loadtest{i}',NOW(6),NOW(6));")
    print(f"INSERT INTO login_info VALUES ({i},'loadtest{i:04d}','{password_hash}',NOW(6),NOW(6));")
    print(f"INSERT INTO seat VALUES ({i},{((i-1)%100)//10+1},{(i-1)%10+1},{(i-1)//100+1},NOW(6),NOW(6));")
